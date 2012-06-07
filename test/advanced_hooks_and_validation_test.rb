require File.join(File.dirname(__FILE__), 'test_helper')

$VERBOSE = false
require 'active_record'
require 'sqlite3'
require 'workflow'

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
class Article < ActiveRecord::Base
  include Workflow
  workflow do
    state :new do
      event :accept, :transitions_to => :accepted, :meta => {:validates_presence_of => [:title, :body]}
      event :reject, :transitions_to => :rejected
    end
    state :accepted do
      event :blame, :transitions_to => :blamed, :meta => {:validates_presence_of => [:title, :body, :blame_reason]}
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

    on_transition do |from, to, triggering_event, *event_args|
      if self.class.superclass.to_s.split("::").first == "ActiveRecord"
        singleton = class << self; self end
        validations = Proc.new {}

        meta = Article.workflow_spec.states[from].events[triggering_event].meta
        fields_to_validate = meta[:validates_presence_of]
        if fields_to_validate
          validations = Proc.new {
            errors.add_on_blank(fields_to_validate) if fields_to_validate
          }
        end

        singleton.send :define_method, :validate_for_transition, &validations
        validate_for_transition
        halt! "Event[#{triggering_event}]'s transitions_to[#{to}] is not valid." unless self.errors.empty?
      end
    end
  end
end

class AdvancedHooksAndValidationTest < ActiveRecordTestCase

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

    exec "INSERT INTO articles(title, body, blame_reason, reject_reason, workflow_state) VALUES('new1', NULL, NULL, NULL, 'new')"
    exec "INSERT INTO articles(title, body, blame_reason, reject_reason, workflow_state) VALUES('new2', 'some content', NULL, NULL, 'new')"
    exec "INSERT INTO articles(title, body, blame_reason, reject_reason, workflow_state) VALUES('accepted1', 'some content', NULL, NULL, 'accepted')"

  end

  def assert_state(title, expected_state, klass = Order)
    o = klass.find_by_title(title)
    assert_equal expected_state, o.read_attribute(klass.workflow_column)
    o
  end

  test 'deny transition from new to accepted because of the missing presence of the body' do
    a = Article.find_by_title('new1');
    assert_raise Workflow::TransitionHalted do
      a.accept!
    end
    assert_state 'new1', 'new', Article
  end

  test 'allow transition from new to accepted because body is present this time' do
    a = Article.find_by_title('new2');
    assert a.accept!
    assert_state 'new2', 'accepted', Article
  end

  test 'allow transition from accepted to blamed because of a blame_reason' do
    a = Article.find_by_title('accepted1');
    a.blame_reason = "Provocant thesis"
    assert a.blame!
    assert_state 'accepted1', 'blamed', Article
  end

  test 'deny transition from accepted to blamed because of no blame_reason' do
    a = Article.find_by_title('accepted1');
    assert_raise Workflow::TransitionHalted do
      assert a.blame!
    end
    assert_state 'accepted1', 'accepted', Article
  end

end

