require File.join(File.dirname(__FILE__), 'test_helper')

$VERBOSE = false
require 'active_record'
require 'sqlite3'
require 'workflow'

ActiveRecord::Migration.verbose = false

# State based validation
# ---------------------------
# This was inspired by the http://github.com/southdesign fork but applies to the state
# rather than the transition, and has some differences in implementation and use.
#
# It closely mirrors the normal ActiveRecord validation.  You supply normal validators on your
# attributes and then specify an :on => <transition_name> to indicate that they are to be 
# applied only when attempting that transition.  If you transition into that
# state and a validation fails, the halt() will be called normally and you can examine
# errors just like any other validation failure.
#
# Shortcomings / to do:
# - If you have overloaded transition names, this will break.  I don't know that it's wise to
#   overload transition names anyway, but I might be persuaded.
# - If you want to generate an exception instead of just a halted? there is currently no way to do it.
#
class Review < ActiveRecord::Base
  validates_presence_of :title, :body, :on => :accept
  validates_presence_of :title, :body, :on => :blame  
  validates :blame_reason, :presence => true, :on => :blame

  include Workflow
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

class StateBasedValidationTest < ActiveRecordTestCase

  def setup
    super

    ActiveRecord::Schema.define do
      create_table :reviews do |t|
        t.string :title
        t.string :body
        t.string :blame_reason
        t.string :reject_reason
        t.string :workflow_state
      end
    end

    exec "INSERT INTO reviews(title, body, blame_reason, reject_reason, workflow_state) VALUES('new1', NULL, NULL, NULL, 'new')"
    exec "INSERT INTO reviews(title, body, blame_reason, reject_reason, workflow_state) VALUES('new2', 'some content', NULL, NULL, 'new')"
    exec "INSERT INTO reviews(title, body, blame_reason, reject_reason, workflow_state) VALUES('accepted1', 'some content', NULL, NULL, 'accepted')"

  end

  def assert_state(title, expected_state, klass = Order)
    o = klass.find_by_title(title)
    assert_equal expected_state, o.read_attribute(klass.workflow_column)
    o
  end

  test 'deny transition to accepted because of the missing presence of the body' do
    a = Review.find_by_title('new1');
    assert a.accept! == false
    assert !a.errors[:body].blank?
    assert_state 'new1', 'new', Review
  end

  test 'allow transition to accepted because body is present this time' do
    a = Review.find_by_title('new2');
    assert a.accept!
    assert_state 'new2', 'accepted', Review
  end

  test 'allow transition to blamed because of a blame_reason' do
    a = Review.find_by_title('accepted1');
    a.blame_reason = "Provocant thesis"
    assert a.blame!
    assert_state 'accepted1', 'blamed', Review
  end

  test 'deny transition to blamed because of no blame_reason' do
    a = Review.find_by_title('accepted1');
    assert a.blame! == false
    assert_state 'accepted1', 'accepted', Review
  end

end

