require 'test_helper'

require 'mongoid'
class MongoidTestCase < Test::Unit::TestCase
  Mongoid.configure do |config|
    if config.respond_to?(:connect_to)  # 3.x
      config.connect_to("workflow_on_mongoid")
    else                                # 2.x
      config.master = Mongo::Connection.new('127.0.0.1', 27017).db("workflow_on_momgoid")
    end
  end

  def teardown
    if Mongoid.respond_to?(:purge!) # 3.x
      Mongoid.purge!
    else                            # 2.x
      Mongoid.master.collections.select do |collection|
        collection.name !~ /system/
      end.each(&:drop)
    end
  end

  def default_test; end
end

# redefine this so it works with mongoid!
def assert_state(title, expected_state, klass = Order)
  puts 'mongoid assert_state'
  o = klass.where(:title => title).first
  assert_equal expected_state, o.send(klass.workflow_column)
  o
end

class MongoidOrder
  include Mongoid::Document

  field :title
  field :workflow_state

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

class MongoidLegacyOrder
  include Mongoid::Document

  field :title
  field :foo_bar

  include Workflow

  workflow_column :foo_bar # use this legacy database column for persistence

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

class MongoidImage
  include Mongoid::Document

  field :title
  field :status

  include Workflow

  workflow_column :status

  workflow do
    state :unconverted do
      event :convert, :transitions_to => :converted
    end
    state :converted
  end
end

class MongoidSmallImage < MongoidImage
end

class MongoidSpecialSmallImage < MongoidSmallImage
end

class MongoidTest < MongoidTestCase

  def setup
    super
    MongoidOrder.create!(:title => 'some MongoidOrder', :workflow_state => 'accepted')
    MongoidLegacyOrder.create!(:title => 'some MongoidOrder', :foo_bar => 'accepted')
  end

  def assert_state(title, expected_state, klass = MongoidOrder)
    o = klass.where(:title => title).first
    assert_equal expected_state, o.send(klass.workflow_column)
    o
  end

  test 'immediately save the new workflow_state on state machine transition' do
    o = assert_state 'some MongoidOrder', 'accepted'
    assert o.ship!
    assert_state 'some MongoidOrder', 'shipped'
  end

  test 'immediately save the new workflow_state on state machine transition with custom column name' do
    o = assert_state 'some MongoidOrder', 'accepted', MongoidLegacyOrder
    assert o.ship!
    assert_state 'some MongoidOrder', 'shipped', MongoidLegacyOrder
  end

  # There was a bug where calling valid? on the record would cause it to be saved
  # see https://github.com/bowsersenior/workflow_on_mongoid/pull/3
  test 'does not save the record when setting initial state' do
    new_order = MongoidOrder.new
    assert new_order.new_record?

    new_order.valid?
    assert new_order.new_record?
  end

  test 'persist workflow_state in the db and reload' do
    o = assert_state 'some MongoidOrder', 'accepted'
    assert_equal :accepted, o.current_state.name
    o.ship!
    o.save!

    assert_state 'some MongoidOrder', 'shipped'

    o.reload
    assert_equal 'shipped', o.send(:workflow_state)
  end

  test 'persist workflow_state in the db with_custom_name and reload' do
    o = assert_state 'some MongoidOrder', 'accepted', MongoidLegacyOrder
    assert_equal :accepted, o.current_state.name
    o.ship!
    o.save!

    assert_state 'some MongoidOrder', 'shipped', MongoidLegacyOrder

    o.reload
    assert_equal 'shipped', o.send(:foo_bar)
  end

  test 'default workflow column should be workflow_state' do
    o = assert_state 'some MongoidOrder', 'accepted'
    assert_equal :workflow_state, o.class.workflow_column
    assert MongoidOrder.fields.keys.include?('workflow_state')
  end

  test 'custom workflow column should be foo_bar' do
    o = assert_state 'some MongoidOrder', 'accepted', MongoidLegacyOrder
    assert_equal :foo_bar, o.class.workflow_column
  end

  test 'should not have workflow_state column if custom workflow_column is specified' do
    assert !( MongoidLegacyOrder.fields.keys.include?('workflow_state') )
  end

  test 'access workflow specification' do
    assert_equal 3, MongoidOrder.workflow_spec.states.length
    assert_equal ['submitted', 'accepted', 'shipped'].sort,
      MongoidOrder.workflow_spec.state_names.map{|n| n.to_s}.sort
  end

  test 'current state object' do
    o = assert_state 'some MongoidOrder', 'accepted'
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
    MongoidOrder.create!(:title => 'nil state', :workflow_state => nil)
    o = MongoidOrder.where(:title =>'nil state').first
    assert o.submitted?, 'if workflow_state is nil, the initial state should be assumed'
    assert !o.shipped?
  end

  test 'initial state immediately set for new objects' do
    o = MongoidOrder.create(:title => 'new object')
    assert_equal 'submitted', o.send(:workflow_state)
  end

  test 'question methods for state' do
    o = assert_state 'some MongoidOrder', 'accepted'
    assert o.accepted?
    assert !o.shipped?
  end

  test 'correct exception for event that is not allowed in current state' do
    o = assert_state 'some MongoidOrder', 'accepted'

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
    class BigMongoidOrder < MongoidOrder
    end

    bo = BigMongoidOrder.new
    assert bo.submitted?
    assert !bo.accepted?
  end

  test 'STI when parent changed the workflow_state column' do
    assert_equal 'status', MongoidImage.workflow_column.to_s
    assert_equal 'status', MongoidSmallImage.workflow_column.to_s
    assert_equal 'status', MongoidSpecialSmallImage.workflow_column.to_s
  end

  test 'Two-level inheritance' do
    class BigMongoidOrder < MongoidOrder
    end

    class EvenBiggerMongoidOrder < BigMongoidOrder
    end

    assert EvenBiggerMongoidOrder.new.submitted?
  end

  test 'Iheritance with workflow definition override' do
    class BigMongoidOrder < MongoidOrder
    end

    class SpecialBigMongoidOrder < BigMongoidOrder
      workflow do
        state :start_big
      end
    end

    special = SpecialBigMongoidOrder.new
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

  test 'halt stops the transition' do
    c = Class.new do
      include Workflow
      workflow do
        state :young do
          event :age, :transitions_to => :old
        end
        state :old
      end

      def age(by=1)
        halt 'too fast' if by > 100
      end
    end

    joe = c.new
    assert joe.young?
    joe.age! 120
    assert joe.young?, 'Transition should have been halted'
    assert_equal 'too fast', joe.halted_because
  end

  test 'halt! raises exception immediately' do
    article_class = Class.new do
      include Workflow
      attr_accessor :too_far
      workflow do
        state :new do
          event :reject, :transitions_to => :rejected
        end
        state :rejected
      end

      def reject(reason)
        halt! 'We do not reject articles unless the reason is important' \
          unless reason =~ /important/i
        self.too_far = "This line should not be executed"
      end
    end

    article = article_class.new
    assert article.new?
    assert_raise Workflow::TransitionHalted do
      article.reject! 'Too funny'
    end
    assert_nil article.too_far
    assert article.new?, 'Transition should have been halted'
    article.reject! 'Important: too short'
    assert article.rejected?, 'Transition should happen now'
  end
end
