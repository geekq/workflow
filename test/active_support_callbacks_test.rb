require File.join(File.dirname(__FILE__), 'test_helper')

$VERBOSE = false
require 'active_record'
require 'sqlite3'
require 'workflow'
require 'workflow/adapters/active_support_callbacks'

ActiveRecord::Migration.verbose = false

class ActiveSupportArticle < ActiveRecord::Base
  include Workflow

  def wrap_in_transaction?
    transition_context.event_args&.first&.fetch(:lock, false)
  end

  def in_transition_validations
    from, to, triggering_event, event_args = transition_context.values

    singleton = class << self; self end
    validations = Proc.new {}

    meta = ActiveSupportArticle.workflow_spec.states[from].events[triggering_event].first.meta
    fields_to_validate = meta[:validates_presence_of]
    if fields_to_validate
      validations = Proc.new {
        #  Don't use deprecated behavior in ActiveRecord 5.
        if ActiveRecord::VERSION::MAJOR == 5
          fields_to_validate.each do |field|
            errors.add(field, :empty) if self[field].blank?
          end
        else
          errors.add_on_blank(fields_to_validate) if fields_to_validate
        end
      }
    end

    singleton.send :define_method, :validate_for_transition, &validations
    validate_for_transition
    halt! "Event[#{triggering_event}]'s transitions_to[#{to}] is not valid." unless self.errors.empty?
    save! if event_args.first&.fetch(:save, false)
  end

  def wrap_in_transaction(&block)
    with_lock(&block)
  end

  def check_for_halt_message
    if transition_context.event_args&.first&.fetch(:halted, false)
      raise "This is a problem"
    else
      yield
    end
  end

  def set_attributes_from_event_args
    args = transition_context.event_args.first || {}
    self.attributes = args[:attributes] if args[:attributes]
  end

  def raise_error_if_flagged
    raise "There was an error" if transition_context.event_args&.first&.fetch(:raise_after_transition, false)
  end

  # around_transition :wrap_in_transaction, if: :wrap_in_transaction?
  around_transition if: :wrap_in_transaction? do |article, transition|
    article.with_lock do
      transition.call
    end
  end

  around_transition :check_for_halt_message
  before_transition :set_attributes_from_event_args, :in_transition_validations
  after_transition :raise_error_if_flagged

  before_transition only: :delete do |article|
    article.message = "Ran transition"
  end

  attr_accessor :message

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
  end
end

class ActiveSupportCallbacksTest < ActiveRecordTestCase

  def setup
    super

    ActiveRecord::Schema.define do
      create_table :active_support_articles do |t|
        t.string :title
        t.string :body
        t.string :blame_reason
        t.string :reject_reason
        t.string :workflow_state
      end
    end

    exec "INSERT INTO active_support_articles(title, body, blame_reason, reject_reason, workflow_state) VALUES('new1', NULL, NULL, NULL, 'new')"
    exec "INSERT INTO active_support_articles(title, body, blame_reason, reject_reason, workflow_state) VALUES('new2', 'some content', NULL, NULL, 'new')"
    exec "INSERT INTO active_support_articles(title, body, blame_reason, reject_reason, workflow_state) VALUES('accepted1', 'some content', NULL, NULL, 'accepted')"

  end

  def assert_state(title, expected_state, klass = Order)
    o = klass.find_by_title(title)
    assert_equal expected_state, o.read_attribute(klass.workflow_column)
    o
  end

  test 'It will deny transition from new to accepted because of the missing presence of the body' do
    a = ActiveSupportArticle.find_by_title('new1');
    assert_raise Workflow::TransitionHalted do
      a.accept!
    end
    assert_state 'new1', 'new', ActiveSupportArticle
  end

  test 'It will allow transition from new to accepted because body is present this time' do
    a = ActiveSupportArticle.find_by_title('new2');
    assert a.accept!
    assert_state 'new2', 'accepted', ActiveSupportArticle
  end

  test 'It will allow transition from accepted to blamed because of a blame_reason' do
    a = ActiveSupportArticle.find_by_title('accepted1');
    a.blame_reason = "Provocant thesis"
    assert a.blame!
    assert_state 'accepted1', 'blamed', ActiveSupportArticle
  end

  test 'It will deny transition from accepted to blamed because of no blame_reason' do
    a = ActiveSupportArticle.find_by_title('accepted1');
    assert_raise Workflow::TransitionHalted do
      assert a.blame!
    end
    assert_state 'accepted1', 'accepted', ActiveSupportArticle
  end

  test "The around transition can halt the execution" do
    a = ActiveSupportArticle.new
    assert_raise RuntimeError, "This is a problem" do
      a.accept! halted: true
    end
    assert a.new?, "The transition should be halted."
  end

  test "It will with a lock, validations don't work on attributes set but not persisted" do
    a = ActiveSupportArticle.find_by_title('new1')
    a.body = 'Blah'
    assert_raise Workflow::TransitionHalted do
      a.accept! lock: true
    end
  end

  test "The validations will work on anything that was persisted" do
    a = ActiveSupportArticle.find_by_title('new1')
    a.update body: 'Blah'
    a.accept! lock: true
    assert_state 'new1', 'accepted', ActiveSupportArticle
  end

  test "The around transition executes the transition" do
    a = ActiveSupportArticle.find_by_title('new1')
    # byebug
    a.accept! lock: true, attributes: {body: 'Blah'}, save: true
    assert_state 'new1', 'accepted', ActiveSupportArticle
    a.reload
    assert_equal 'Blah', a.body
  end

  test "Any exception raised later in the chain rolls back the transaction" do
    a = ActiveSupportArticle.find_by_title('new1')
    assert_raise RuntimeError, "There was an error" do
      a.accept! lock: true, attributes: {body: 'Blah'}, save: true, raise_after_transition: true
    end
    assert_state 'new1', 'new', ActiveSupportArticle
    assert_equal 'Blah', a.body, 'The body text was set'
    a.reload
    assert_nil a.body, 'But the body text was not persisted.'
  end

  test "Event-specific transition callbacks will run" do
    article = ActiveSupportArticle.find_by_title 'new1'
    article.reject!
    assert_nil article.message
    article.delete!
    assert_equal 'Ran transition', article.message
  end

  test "Halting the transition chain in a before_transition" do
    subclass = Class.new(ActiveSupportArticle)
    subclass.prepend_before_transition only: :delete do |article|
      throw :abort
    end
    article = subclass.find_by_title 'new1'
    assert article.reject!
    assert_nil article.message
    assert !article.delete!
    assert_nil article.message
  end
end
