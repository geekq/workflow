require File.join(File.dirname(__FILE__), 'test_helper')

$VERBOSE = false
require 'active_record'
require 'sqlite3'
require 'workflow'

ActiveRecord::Migration.verbose = false

class Article < ActiveRecord::Base
  include Workflow

  workflow do
    state :new
    state :accepted
  end
end

class ActiveRecordScopesTest < ActiveRecordTestCase

  def setup
    super

    ActiveRecord::Schema.define do
      create_table :articles do |t|
        t.string :title
        t.string :body
        t.string :blame_reason
        t.string :reject_reason
        t.string :workflow_state
      end
    end
  end

  def assert_state(title, expected_state, klass = Order)
    o = klass.find_by_title(title)
    assert_equal expected_state, o.read_attribute(klass.workflow_column)
    o
  end

  test 'have "with_new_state" scope' do
    assert_respond_to Article, :with_new_state
  end

  test 'have "with_accepted_state" scope' do
    assert_respond_to Article, :with_accepted_state
  end
end

