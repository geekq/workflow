require File.join(File.dirname(__FILE__), 'test_helper')

$VERBOSE = false
require 'active_record'
require 'sqlite3'
require 'workflow'
require 'mocha'
#require 'ruby-debug'

ActiveRecord::Migration.verbose = false

class Order < ActiveRecord::Base
  include Workflow
  workflow do
    state :submitted do
      event :accept, :transitions_to => :accepted, :meta => {:doc_weight => 8} do |reviewer, args|
      end
    end
    state :accepted do
      event :ship, :transitions_to => :shipped
    end
    state :shipped
  end

end

class MainTest < Test::Unit::TestCase

  def exec(sql)
    ActiveRecord::Base.connection.execute sql
  end

  def setup
    ActiveRecord::Base.establish_connection(
      :adapter => "sqlite3",
      :database  => ":memory:" #"tmp/test"
    )
    ActiveRecord::Base.connection.reconnect! # eliminate ActiveRecord warning. TODO: delete as soon as ActiveRecord is fixed

    ActiveRecord::Schema.define do
      create_table :orders do |t|
        t.string :title, :null => false
        t.string :workflow_state
      end
    end

    exec "INSERT INTO orders(title, workflow_state) VALUES('some order', 'accepted')"
  end

  def teardown
    ActiveRecord::Base.connection.disconnect!
  end

  def assert_state(title, expected_state)
    o = Order.find_by_title(title)
    assert_equal expected_state, o.read_attribute(:workflow_state)
    o
  end

  test 'immediatly save the new workflow_state on state machine transition' do
    o = assert_state 'some order', 'accepted'
    o.ship!
    assert_state 'some order', 'shipped'
  end

  test 'persist workflow_state in the db and reload' do
    o = assert_state 'some order', 'accepted'
    assert_equal :accepted, o.current_state.name
    o.ship!
    o.save!

    assert_state 'some order', 'shipped'

    o.reload
    assert_equal 'shipped', o.read_attribute(:workflow_state)
  end

  test 'access workflow specification' do
    assert_equal 3, Order.workflow_spec.states.length
  end

  test 'current state object' do
    o = assert_state 'some order', 'accepted'
    assert_equal 'accepted', o.current_state.to_s
    assert_equal 1, o.current_state.events.length
  end

  test 'on_entry and on_exit invoked' do
    c = Class.new
    callbacks = mock()
    callbacks.expects(:my_on_exit_new).once
    callbacks.expects(:my_on_entry_old).once
    c.class_eval do
      include Workflow
      workflow do
        state :new do
          event :age, :transitions_to => :old
        end
        on_exit do
          callbacks.my_on_exit_new
        end
        state :old
        on_entry do
          callbacks.my_on_entry_old
        end
        on_exit do
          fail "wrong on_exit executed"
        end
      end
    end

    o = c.new
    assert_equal 'new', o.current_state.to_s
    o.age!
  end

  test 'on_transition invoked' do
    callbacks = mock()
    callbacks.expects(:on_tran).once # this is validated at the end
    c = Class.new
    c.class_eval do
      include Workflow
      workflow do
        state :one do
          event :increment, :transitions_to => :two
        end
        state :two
        on_transition do |from, to, triggering_event, *event_args|
          callbacks.on_tran
        end
      end
    end
    assert_not_nil c.workflow_spec.on_transition_proc
    c.new.increment!
  end

  test 'access event meta information' do
    c = Class.new
    c.class_eval do
      include Workflow
      workflow do
        state :main, :meta => {:importance => 8}
        state :supplemental, :meta => {:importance => 1}
      end
    end
    assert_equal 1, c.workflow_spec.states[:supplemental].meta[:importance]
  end

  test 'initial state' do
    c = Class.new
    c.class_eval do
      include Workflow
      workflow { state :one; state :two }
    end
    assert_equal 'one', c.new.current_state.to_s
  end

  test 'nil as initial state' do
    exec "INSERT INTO orders(title, workflow_state) VALUES('nil state', NULL)"
    o = Order.find_by_title('nil state')
    assert o.submitted?, 'if workflow_state is nil, the initial state should be assumed'
    assert !o.shipped?
  end

  test 'initial state immediately set as ActiveRecord attribute for new objects' do
    o = Order.create(:title => 'new object')
    assert_equal 'submitted', o.read_attribute(:workflow_state)
  end

  test 'question methods for state' do
    o = assert_state 'some order', 'accepted'
    assert o.accepted?
    assert !o.shipped?
  end

  test 'correct exception for event, that is not allowed in current state' do
    o = assert_state 'some order', 'accepted'
    assert_raise Workflow::NoTransitionAllowed do
      o.accept!
    end
  end

  test 'multiple events with the same name and different arguments lists from different states'

  test 'implicit transition callback' do
    args = mock()
    args.expects(:my_tran).once # this is validated at the end
    c = Class.new
    c.class_eval do
      include Workflow
      def my_transition(args)
        args.my_tran
      end
      workflow do
        state :one do
          event :my_transition, :transitions_to => :two
        end
        state :two
      end
    end
    c.new.my_transition!(args)
  end

  test 'Single table inheritance (STI)' do
    class BigOrder < Order
    end

    bo = BigOrder.new
    assert bo.submitted?
    assert !bo.accepted?
  end

  test 'Two-level inheritance' do
    class BigOrder < Order
    end

    class EvenBiggerOrder < BigOrder
    end

    assert EvenBiggerOrder.new.submitted?
  end

  test 'Iheritance with workflow definition override' do
    class BigOrder < Order
    end

    class SpecialBigOrder < BigOrder
      workflow do
        state :start_big
      end
    end

    special = SpecialBigOrder.new
    assert_equal 'start_big', special.current_state.to_s
  end

  test 'Better error message for missing target state' do
    class Problem
      include Workflow
      workflow do
        state :initial do
          event :solve, :transitions_to => :solved
        end
      end
    end
    assert_raise Workflow::WorkflowError do
      Problem.new.solve!
    end
  end

  # Intermixing of transition graph definition (states, transitions)
  # on the one side and implementation of the actions on the other side
  # for a bigger state machine can introduce clutter.
  #
  # To reduce this clutter it is now possible to use state entry- and
  # exit- hooks defined through a naming convention. For example, if there
  # is a state :pending, then you can hook in by defining method
  # `def on_pending_exit(new_state, event, *args)` instead of using a
  # block:
  #
  #     state :pending do
  #       on_entry do
  #         # your implementation here
  #       end
  #     end
  #
  # If both a function with a name according to naming convention and the
  # on_entry/on_exit block are given, then only on_entry/on_exit block is used.
  test 'on_entry and on_exit hooks in separate methods' do
    c = Class.new
    c.class_eval do
      include Workflow
      attr_reader :history
      def initialize
        @history = []
      end
      workflow do
        state :new do
          event :next, :transitions_to => :next_state
        end
        state :next_state
      end

      def on_next_state_entry(prior_state, event, *args)
        @history << "on_next_state_entry #{event} #{prior_state} ->"
      end

      def on_new_exit(new_state, event, *args)
        @history << "on_new_exit #{event} -> #{new_state}"
      end
    end

    o = c.new
    assert_equal 'new', o.current_state.to_s
    assert_equal [], o.history
    o.next!
    assert_equal ['on_new_exit next -> next_state', 'on_next_state_entry next new ->'], o.history

  end

  test 'diagram generation' do
    begin
      $stdout = StringIO.new('', 'w')
      Workflow::create_workflow_diagram(Order, 'doc')
      assert_match(/open.+\.pdf/, $stdout.string,
        'PDF should be generate and a hint be given to the user.')
    ensure
      $stdout = STDOUT
    end
  end
end

