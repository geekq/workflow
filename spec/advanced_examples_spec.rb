require 'spec_helper'

RSpec.describe "Advanced Examples" do
  class AdvancedExample
    include Workflow
    workflow do
      define_revert_events!
      state :new do
        event :submit, :transitions_to => :awaiting_review
      end
      state :awaiting_review do
        event :review, :transitions_to => :being_reviewed
      end
      state :being_reviewed do
        event :accept, :transitions_to => :accepted
        event :reject, :transitions_to => :rejected
      end
      state :accepted do
      end
      state :rejected do
      end
    end
  end

  describe "#63 Undoing Events" do
    subject {AdvancedExample.new}
    it {is_expected.to be_new}
    it "should be able to progress as normal" do
      expect {
        subject.submit!
      }.to change {
        subject.current_state.name
      }.from(:new).to(:awaiting_review)
    end

    describe "Reversion events" do
      before do
        subject.submit!
      end
      it "should have an additional event for reverting the submit" do
        expect(subject.current_state.events.keys).to include(:revert_submit)
        expect(subject.current_state.events.keys).to include(:review)
      end

      it "should be able to revert the submit" do
        expect {
          subject.revert_submit!
        }.to change {
          subject.current_state.name
        }.from(:awaiting_review).to(:new)
      end
    end
  end

  describe "#92 - Load ad-hoc workflow specification" do
    let(:adhoc_class) {
      c = Class.new
      c.send :include, Workflow
      c
    }

    let(:workflow_spec) {
      Workflow::Specification.new do
        state :one do
          event :dynamic_transition, :transitions_to => :one_a
        end
        state :one_a
      end
    }

    before do
      adhoc_class.send :assign_workflow, workflow_spec
    end

    subject {adhoc_class.new}

    it "should be able to load and run dynamically generated state transitions" do
      expect {
        subject.dynamic_transition!(1)
      }.to change {
        subject.current_state.name
      }.from(:one).to(:one_a)
    end

    it "should not have a revert event" do
      states = adhoc_class.workflow_spec.states.collect(&:events).flatten.collect(&:keys).flatten.uniq.map(&:to_s)
      expect(states.select{|t| t =~ /^revert/}).to be_empty
    end

    describe "unless you want revert events" do
      let(:workflow_spec) {
        Workflow::Specification.new do
          define_revert_events!
          state :one do
            event :dynamic_transition, :transitions_to => :one_a
          end
          state :one_a
        end
      }

      it "should have revert events" do
        states = adhoc_class.workflow_spec.states.collect(&:events).flatten.collect(&:keys).flatten.uniq.map(&:to_s)
        expect(states.select{|t| t =~ /^revert/}).not_to be_empty
      end
    end
  end
end
