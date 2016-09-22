require "spec_helper"

RSpec.describe "Active Record Scopes", type: :active_record_examples do
  include_context "ActiveRecord Setup"
  class Article < ActiveRecord::Base
    include Workflow

    workflow do
      state :new do
        on :accept, to: :accepted
      end
      state :accepted
    end
  end

  before do
    ActiveRecord::Schema.define do
      create_table :articles do |t|
        t.string :title
        t.string :body
        t.string :blame_reason
        t.string :reject_reason
        t.string :workflow_state
        t.datetime :created_at
        t.datetime :updated_at
      end
    end
  end

  describe "#load_workflow_state" do
    it "should return nil if the database value is nil" do
      a = Article.new(workflow_state: nil)
      expect(a.current_state).not_to be_nil
    end
  end

  describe "#persist_workflow_state" do
    describe "when the object has not been persisted" do
      it "sets the attribute on the object" do
        a = Article.new
        a.accept!
        expect(a).to be_accepted
      end
    end

    describe "#touch_on_update_column" do
      subject {Article.create}
      describe "When turned off" do
        before do
          Workflow.config.touch_on_update_column = false
        end
        it "should not update the update_at time" do
          expect(subject.updated_at).not_to be_nil
          expect {
            subject.accept!
          }.not_to change {
            Article.last.updated_at
          }
        end
      end

      describe "When enabled" do
        before do
          Workflow.config.touch_on_update_column = true
        end
        after do
          Workflow.config.touch_on_update_column = false
        end
        it "should update the update_at time" do
          expect(subject.updated_at).not_to be_nil
          expect {
            subject.accept!
          }.to change {
            Article.last.updated_at
          }
        end
      end
    end

    describe "when the object has been persisted" do
      describe "If configured to persist state immediately" do
        before do
          Workflow.config.persist_workflow_state_immediately = true
        end
        it "should update the column" do
          a = Article.create
          expect(a).to be_new
          a.accept!
          a.reload
          expect(a).to be_accepted
        end
      end

      describe "If configured not to persist state immediately" do
        before do
          Workflow.config.persist_workflow_state_immediately = false
        end
        after do
          Workflow.config.persist_workflow_state_immediately = true
        end
        it "should update the column" do
          a = Article.create
          expect(a).to be_new
          a.accept!
          expect(a).to be_accepted
          a.reload
          expect(a).not_to be_accepted
        end
      end
    end
  end

  subject {Article}
  it {is_expected.to respond_to(:with_new_state)}
  it {is_expected.to respond_to(:with_accepted_state)}
  it {is_expected.to respond_to(:without_new_state)}
  it {is_expected.to respond_to(:without_accepted_state)}
end
