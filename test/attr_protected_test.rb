require 'test_helper'

$VERBOSE = false
require 'active_record'
require 'logger'
require 'sqlite3'
require 'workflow'
require 'mocha/setup'
require 'stringio'
require 'protected_attributes' if ActiveRecord::VERSION::MAJOR >= 4

ActiveRecord::Migration.verbose = false

class AttrProtectedTestOrder < ActiveRecord::Base
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

  attr_accessible :title # protecting all the other attributes

end

AttrProtectedTestOrder.logger = Logger.new(STDOUT) # active_record 2.3 expects a logger instance
AttrProtectedTestOrder.logger.level = Logger::WARN # switch to Logger::DEBUG to see the SQL statements

class AttrProtectedTest < ActiveRecordTestCase

  def setup
    super

    ActiveRecord::Schema.define do
      create_table :attr_protected_test_orders do |t|
        t.string :title, :null => false
        t.string :workflow_state
      end
    end

    exec "INSERT INTO attr_protected_test_orders(title, workflow_state) VALUES('order1', 'submitted')"
    exec "INSERT INTO attr_protected_test_orders(title, workflow_state) VALUES('order2', 'accepted')"
    exec "INSERT INTO attr_protected_test_orders(title, workflow_state) VALUES('order3', 'accepted')"
    exec "INSERT INTO attr_protected_test_orders(title, workflow_state) VALUES('order4', 'accepted')"
    exec "INSERT INTO attr_protected_test_orders(title, workflow_state) VALUES('order5', 'accepted')"
    exec "INSERT INTO attr_protected_test_orders(title, workflow_state) VALUES('protected order', 'submitted')"
  end

  def assert_state(title, expected_state, klass = AttrProtectedTestOrder)
    o = klass.find_by_title(title)
    assert_equal expected_state, o.read_attribute(klass.workflow_column)
    o
  end

  test 'cannot mass-assign workflow_state if attr_protected' do
     o = AttrProtectedTestOrder.find_by_title('order1')
     assert_equal 'submitted', o.read_attribute(:workflow_state)
     AttrProtectedTestOrder.logger.level = Logger::ERROR # ignore warnings
     o.update_attributes :workflow_state => 'some_bad_value'
     AttrProtectedTestOrder.logger.level = Logger::WARN
     assert_equal 'submitted', o.read_attribute(:workflow_state)
     o.update_attribute :workflow_state, 'some_overridden_value'
     assert_equal 'some_overridden_value', o.read_attribute(:workflow_state)
   end

  test 'immediately save the new workflow_state on state machine transition' do
    o = assert_state 'order2', 'accepted'
    assert o.ship!
    assert_state 'order2', 'shipped'
  end

  test 'persist workflow_state in the db and reload' do
    o = assert_state 'order3', 'accepted'
    assert_equal :accepted, o.current_state.name
    o.ship! # should save in the database, no `o.save!` needed

    assert_state 'order3', 'shipped'

    o.reload
    assert_equal 'shipped', o.read_attribute(:workflow_state)
  end

  test 'default workflow column should be workflow_state' do
    o = assert_state 'order4', 'accepted'
    assert_equal :workflow_state, o.class.workflow_column
  end

  test 'access workflow specification' do
    assert_equal 3, AttrProtectedTestOrder.workflow_spec.states.length
    assert_equal ['submitted', 'accepted', 'shipped'].sort,
      AttrProtectedTestOrder.workflow_spec.state_names.map{|n| n.to_s}.sort
  end

  test 'current state object' do
    o = assert_state 'order5', 'accepted'
    assert_equal 'accepted', o.current_state.to_s
    assert_equal 1, o.current_state.events.length
  end

end

