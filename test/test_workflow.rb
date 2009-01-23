require 'rubygems'
require 'test/unit'
require 'active_record'
require 'workflow'

class << Test::Unit::TestCase
  def test(name, &block)
    test_name = :"test_#{name.gsub(' ','_')}"
    raise ArgumentError, "#{test_name} is already defined" if self.instance_methods.include? test_name.to_s
    define_method test_name, &block
  end
end

class WorkflowTest < Test::Unit::TestCase

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

  def exec(sql)
    ActiveRecord::Base.connection.execute sql
  end

  def setup
    ActiveRecord::Base.establish_connection(
      :adapter => "sqlite3",
      :database  => ":memory:" #"tmp/test"
    )

    ActiveRecord::Schema.define do
      create_table :orders do |t|
        t.string :title, :null => false
        t.string :workflow_state
      end
    end

    exec "INSERT INTO orders(title, workflow_state) VALUES('some order', 'accepted')"
  end

  test 'persisting workflow_state in the db' do
    o = Order.find_by_title('some order')
    assert_equal 'accepted', o.read_attribute(:workflow_state)
    assert_equal :accepted, o.workflow.current_state.name
    o.ship
    o.save!

    o2 = Order.find_by_title('some order')
    assert_equal 'shipped', o2.read_attribute(:workflow_state)

    o.reload
    assert_equal 'shipped', o.read_attribute(:workflow_state)
  end
end