require File.join(File.dirname(__FILE__), 'test_helper')

require 'active_record'
require 'sqlite3'
require 'workflow'
require 'mocha/setup'
require 'stringio'

ActiveRecord::Migration.verbose = false

class Issue < ActiveRecord::Base
  include Workflow

  workflow do
    state :new do
      event :accept, :transitions_to => :accepted
    end
    state :accepted
  end
end

class ActiveRecordMassAssignmentTest < ActiveRecordTestCase

  def setup
    super

    ActiveRecord::Schema.define do
      create_table :issues do |t|
        t.string :title, :null => false
        t.string :workflow_state
      end
    end

    exec "INSERT INTO issues(title, workflow_state) VALUES('mass assignment problem', 'new')"
  end

  test 'cannot mass-assign workflow_state if attr_protected' do
    Issue.attr_protected :workflow_state

    # use the *old* update_attributes method
    Issue.class_eval do
      def persist_workflow_state(new_value)
        update_attributes self.class.workflow_column => new_value
      end
    end

    issue = Issue.first
    assert_equal :new, issue.current_state.to_sym

    # 'workflow_state' is sanitized(removed) from the attributes to be saved,
    # so nothing was actually saved in the following method.
    #
    # See: https://github.com/rails/rails/blob/3-2-stable/activemodel/lib/active_model/mass_assignment_security/sanitizer.rb#L10
    issue.accept!

    assert_equal :new, issue.current_state.to_sym # the new state was *NOT* saved!
    assert !issue.accepted?

    # fix the mass assignment problem
    Issue.class_eval do
      def persist_workflow_state(new_value)
        self.send("#{self.class.workflow_column}=", new_value)
        self.save!
      end
    end

    issue = Issue.first
    assert_equal :new, issue.current_state.to_sym

    issue.accept!

    assert_equal :accepted, issue.current_state.to_sym # the new state was saved
    assert issue.accepted?
  end
end
