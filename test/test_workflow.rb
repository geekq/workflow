require 'rubygems'
require 'test/unit'
require 'active_record'
require 'workflow'

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
    ActiveRecord::Base.establish_connection(
      :adapter => "sqlite3",
      :database  => ":memory:" #"tmp/test"
    )
    
    ActiveRecord::Base.silence {
      ActiveRecord::Schema.define do
        create_table :orders do |t|
          t.string :title, :null => false
          t.string :workflow_state
        end
      end
    }

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
    o.ship
    assert_state 'some order', 'shipped'
  end

  test 'persist workflow_state in the db and reload' do
    o = assert_state 'some order', 'accepted'
    assert_equal :accepted, o.workflow.current_state.name
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
    assert_equal 'accepted', o.current_state.to_s
    assert_equal 1, o.current_state.events.length
  end
end