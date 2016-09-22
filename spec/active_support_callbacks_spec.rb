require 'spec_helper'

RSpec.describe "Callbacks" do

  class ActiveSupportArticle < ActiveRecord::Base
    include Workflow

    def wrap_in_transaction?
      transition_context.event_args&.first&.fetch(:lock, false)
    end

    def in_transition_validations
      from, to, triggering_event, event_args = transition_context.values

      singleton = class << self; self end
      validations = Proc.new {}

      meta = ActiveSupportArticle.workflow_spec.find_state(from).find_event(triggering_event).meta
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
        on :accept, to: :accepted, :meta => {:validates_presence_of => [:title, :body]}
        on :reject, to: :rejected
      end
      state :accepted do
        on :blame, to: :blamed, :meta => {:validates_presence_of => [:title, :body, :blame_reason]}
        on :delete, to: :deleted
      end
      state :rejected do
        on :delete, to: :deleted
      end
      state :blamed do
        on :delete, to: :deleted
      end
      state :deleted do
        on :accept, to: :accepted
      end
    end
  end

  before do
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


  it 'should deny transition from new to accepted because of the missing presence of the body' do
    a = ActiveSupportArticle.find_by_title('new1');
    expect {a.accept!}.to raise_error(Workflow::TransitionHaltedError)
    expect(a).to have_persisted_state(:new)
  end

  it 'should allow transition from new to accepted because body is present this time' do
    a = ActiveSupportArticle.find_by_title('new2');
    expect(a.accept!).to be_truthy
    expect(a).to have_persisted_state(:accepted)
  end

  it 'should allow transition from accepted to blamed because of a blame_reason' do
    a = ActiveSupportArticle.find_by_title('accepted1');
    a.blame_reason = "Provocant thesis"
    expect {a.blame!}.to change{
      ActiveSupportArticle.find_by_title('accepted1').workflow_state
    }.from('accepted').to('blamed')
  end

  it 'should deny transition from accepted to blamed because of no blame_reason' do
    a = ActiveSupportArticle.find_by_title('accepted1');
    expect {
      expect {
        assert a.blame!
      }.to raise_error(Workflow::TransitionHaltedError)
    }.not_to change {ActiveSupportArticle.find_by_title('accepted1').workflow_state}
  end

  describe "Around Transition" do
    it "can halt the execution" do
      a = ActiveSupportArticle.new
      expect {
        a.accept! halted: true
      }.to raise_error(RuntimeError, "This is a problem")

      expect(a).to be_new
    end

    describe "halting callback chain in before transition callbacks" do
      let(:subclass) {Class.new(ActiveSupportArticle)}
      subject {subclass.find_by_title 'new1'}

      describe "when there is no :abort thrown" do
        it "should complete the transition" do
          expect {
            subject.reject!
          }.to change {
            subject.class.find(subject.id).workflow_state
          }.from('new').to('rejected')
        end
      end

      describe "when halt is called" do
        before do
          subclass.prepend_before_transition only: :reject do |article|
            halt
          end
        end
        it "should not complete the :reject transition" do
          expect {
            subject.reject!
          }.not_to change {
            subject.class.find(subject.id).workflow_state
          }
        end
        it "should allow non-matching transitions to continue" do
          expect {
            subject.accept! lock: true, attributes: {body: 'Blah'}, save: true
          }.to change {
            subject.class.find(subject.id).workflow_state
          }.from('new').to('accepted')
        end
      end
    end

    describe "locking behavior" do
      subject {ActiveSupportArticle.find_by_title('new1')}

      describe "When attributes are set but not persisted before the state transition" do
        before do
          subject.body = 'Blah'
        end
        it "should halt the transition" do
          expect {
            subject.accept! lock: true
          }.to raise_error(Workflow::TransitionHaltedError)
        end
      end

      describe "When attribute changes are all persisted before the state transition" do
        before do
          subject.update body: 'Blah'
        end
        it "should complete the state change" do
          expect {
            subject.accept! lock: true
          }.to change {
            subject.class.find(subject.id).workflow_state
          }.from('new').to('accepted')
        end
      end

      describe "When attribute changes are passed along as a part of the transition" do
        it "executes the transition" do
          expect {
            subject.accept! lock: true, attributes: {body: 'Blah'}, save: true
          }.to change {
            subject.class.find(subject.id).workflow_state
          }.from('new').to('accepted')
        end

        it "updates the body of the article" do
          expect {
            subject.accept! lock: true, attributes: {body: 'Blah'}, save: true
          }.to change {
            subject.class.find(subject.id).body
          }.from(nil).to('Blah')
        end
      end

      describe "when a downstream error occurs after changes were persisted" do
        it "rolls back the changes to the workflow state" do
          expect {
            expect {
              subject.accept! lock: true, attributes: {body: 'Blah'}, save: true, raise_after_transition: true
            }.to raise_error(RuntimeError, "There was an error")
          }.not_to change {
            subject.class.find(subject.id).workflow_state
          }
        end

        it "rolls back the changes to the attributes" do
          expect {
            expect {
              subject.accept! lock: true, attributes: {body: 'Blah'}, save: true, raise_after_transition: true
            }.to raise_error(RuntimeError, "There was an error")
          }.not_to change {
            subject.class.find(subject.id).body
          }
        end
      end
    end
  end


  # test "Event-specific transition callbacks will run" do
  #   article = ActiveSupportArticle.find_by_title 'new1'
  #   article.reject!
  #   assert_nil article.message
  #   article.delete!
  #   assert_equal 'Ran transition', article.message
  # end
end
