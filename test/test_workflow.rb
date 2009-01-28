require 'rubygems'
require 'test/unit'
old_verbose, $VERBOSE = $VERBOSE, nil
require 'active_record'
require 'sqlite3'
$VERBOSE = old_verbose
require 'workflow'
require 'mocha'
#require 'ruby-debug'

ActiveRecord::Migration.verbose = false

class << Test::Unit::TestCase
  def test(name, &block)
    test_name = :"test_#{name.gsub(' ','_')}"
    raise ArgumentError, "#{test_name} is already defined" if self.instance_methods.include? test_name.to_s
    if block
      define_method test_name, &block
    else
      puts "PENDING: #{name}"
    end
  end
end

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

class WorkflowTest < Test::Unit::TestCase

  def exec(sql)
    ActiveRecord::Base.connection.execute sql
  end

  def setup
    old_verbose, $VERBOSE = $VERBOSE, nil # eliminate sqlite3 warning. TODO: delete as soon as sqlite-ruby is fixed
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
    $VERBOSE = old_verbose
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
    o.ship
    assert_state 'some order', 'shipped'
  end

  test 'persist workflow_state in the db and reload' do
    o = assert_state 'some order', 'accepted'
    assert_equal :accepted, o.current_state.name
    o.ship
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

  test 'on_transition invoked'

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
    o.age
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

  test 'question methods for state' do
    o = assert_state 'some order', 'accepted'
    assert o.accepted?
    assert !o.shipped?
  end

  test 'correct exception for event, that is not allowed in current state' do
    o = assert_state 'some order', 'accepted'
    assert_raise Workflow::NoTransitionAllowed do
      o.accept
    end
  end

  test 'multiple events with the same name and different arguments lists from different states'
end