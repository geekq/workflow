require File.join(File.dirname(__FILE__), 'test_helper')

$VERBOSE = false
require 'active_record'
require 'sqlite3'
require 'workflow'
require 'mocha/setup'
require 'stringio'
#require 'ruby-debug'

ActiveRecord::Migration.verbose = false

module AttrProtected
  extend ActiveSupport::Concern
  included do
    attr_protected :workflow_state
  end
end

class ProtectedOrder < ActiveRecord::Base
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

class AttrProtectedTest < ActiveRecordTestCase

  def setup
    super

    ActiveRecord::Schema.define do
      create_table :protected_orders do |t|
        t.string :title, :null => false
        t.string :workflow_state
      end
    end

    exec "INSERT INTO protected_orders(title, workflow_state) VALUES('some order', 'accepted')"
    exec "INSERT INTO protected_orders(title, workflow_state) VALUES('protected order', 'submitted')"
    
    ProtectedOrder.extend(AttrProtected)
  end

  def assert_state(title, expected_state, klass = ProtectedOrder)
    o = klass.find_by_title(title)
    assert_equal expected_state, o.read_attribute(klass.workflow_column)
    o
  end

  test 'cannot mass-assign workflow_state if attr_protected' do
     o = ProtectedOrder.find_by_title('some order')
     o.update_attributes :workflow_state => 'some_bad_value'
     assert_equal 'submitted', o.read_attribute(:workflow_state)
     o.update_attribute :workflow_state, 'some_overridden_value'
     assert_equal 'some_overridden_value', o.read_attribute(:workflow_state)
   end

  test 'immediately save the new workflow_state on state machine transition' do
    o = assert_state 'some order', 'accepted'
    assert o.ship!
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

  test 'default workflow column should be workflow_state' do
    o = assert_state 'some order', 'accepted'
    assert_equal :workflow_state, o.class.workflow_column
  end

  test 'access workflow specification' do
    assert_equal 3, Order.workflow_spec.states.length
    assert_equal ['submitted', 'accepted', 'shipped'].sort,
      Order.workflow_spec.state_names.map{|n| n.to_s}.sort
  end

  test 'current state object' do
    o = assert_state 'some order', 'accepted'
    assert_equal 'accepted', o.current_state.to_s
    assert_equal 1, o.current_state.events.length
  end

end

