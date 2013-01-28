require 'test_helper'
require 'active_record'
require 'logger'
require 'sqlite3'
require 'workflow'
require 'mocha/setup'
require 'stringio'

ActiveRecord::Migration.verbose = false

class PersistenceTestOrder < ActiveRecord::Base
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

PersistenceTestOrder.logger = Logger.new(STDOUT) # active_record 2.3 expects a logger instance
PersistenceTestOrder.logger.level = Logger::WARN # switch to Logger::DEBUG to see the SQL statements

class PersistenceTest < ActiveRecordTestCase

  def setup
    super

    ActiveRecord::Schema.define do
      create_table :persistence_test_orders do |t|
        t.string :title, :null => false
        t.string :workflow_state
      end
    end

    exec "INSERT INTO persistence_test_orders(title, workflow_state) VALUES('order6', 'accepted')"
  end

  def assert_state(title, expected_state, klass = PersistenceTestOrder)
    o = klass.find_by_title(title)
    assert_equal expected_state, o.read_attribute(klass.workflow_column)
    o
  end

  test 'ensure other dirty attributes are not saved on state change' do
    o = assert_state 'order6', 'accepted'
    o.title = 'going to change the title'
    assert o.changed?
    o.ship!
    assert o.changed?, 'title should not be saved and the change still stay pending'
  end

end

