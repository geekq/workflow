require File.join(File.dirname(__FILE__), 'test_helper')

$VERBOSE = false
require 'active_record'
require 'sqlite3'
require 'workflow'
require 'workflow/adapters/active_support_callbacks'

ActiveRecord::Migration.verbose = false

# Transition based validation
# ---------------------------
# If you are using ActiveRecord you might want to define different validations
# for different transitions. There is a `validates_presence_of` hook that let's
# you specify the attributes that need to be present for an successful transition.
# If the object is not valid at the end of the transition event the transition
# is halted and a TransitionHalted exception is thrown.
#
# Here is a sample that illustrates how to use the presence validation:
# (use case suggested by http://github.com/southdesign)
class ActiveRecordArticle < ActiveRecord::Base
  include Workflow

  [:title, :body].each do |attr|
    validates attr, presence: true, if: :transitioning_via_event_accept?
  end

  [:title, :body, :blame_reason].each do |attr|
    validates attr, presence: true, if: :transitioning_via_event_blame?
  end

  halt_unless_valid!

  workflow do
    state :new do
      event :accept, :transitions_to => :accepted
      event :reject, :transitions_to => :rejected
    end
    state :accepted do
      event :blame, :transitions_to => :blamed
      event :delete, :transitions_to => :deleted
    end
    state :rejected do
      event :delete, :transitions_to => :deleted
    end
    state :blamed do
      event :delete, :transitions_to => :deleted
    end
    state :deleted do
      event :accept, :transitions_to => :accepted
    end
  end
end

class ActiveRecordValidationsTest < ActiveRecordTestCase

  def setup
    super

    ActiveRecord::Schema.define do
      create_table :active_record_articles do |t|
        t.string :title
        t.string :body
        t.string :blame_reason
        t.string :reject_reason
        t.string :workflow_state
      end
    end

    exec "INSERT INTO active_record_articles(title, body, blame_reason, reject_reason, workflow_state) VALUES('new1', NULL, NULL, NULL, 'new')"
    exec "INSERT INTO active_record_articles(title, body, blame_reason, reject_reason, workflow_state) VALUES('new2', 'some content', NULL, NULL, 'new')"
    exec "INSERT INTO active_record_articles(title, body, blame_reason, reject_reason, workflow_state) VALUES('accepted1', 'some content', NULL, NULL, 'accepted')"

  end

  test "Validates presence on transition" do
    article = ActiveRecordArticle.find_by_title 'new1'
    assert !article.can_transition?(:accept)
    assert !article.accept!

  end

end
