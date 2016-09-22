require 'spec_helper'

RSpec.describe "Workflow::State" do
  describe "Basic Usage" do
    subject {
      new_workflow_class do
        state :initial_state do
          on :event1, to: :another_state
          on :event2, to: :another_state
        end
        state :another_state
      end.workflow_spec.states.first
    }
    it "Defines Events" do
      expect(subject.events.length).to eq 2
    end
  end

  describe "Error Conditions" do
    describe "If no target transition is given for an event" do
      it "should raise an error" do
        expect {
          new_workflow_class do
            state :initial_state do
              on :event1 do
              end
            end
          end
        }.to raise_error(Workflow::Errors::WorkflowDefinitionError, "No transitions defined for event [event1] on state [initial_state]")
      end
    end
    describe "When defining an event for the second time on the same state" do
      it "should raise an error" do
        expect {
          new_workflow_class do
            state :initial_state do
              on :event1, to: :real_state
              on :event1, to: :real_state
            end
          end
        }.to raise_error(Workflow::Errors::WorkflowDefinitionError, "Already defined an event [event1] for state[initial_state]")
      end
    end
    describe "When defining an event transition with a nonexistent target state" do
      it "should raise an error" do
        expect {
          new_workflow_class do
            state(:initial_state) {on :event1, to: :nonexistent_state}
          end
        }.to raise_error(Workflow::Errors::WorkflowDefinitionError, "Event event1 transitions to nonexistent_state but there is no such state.")
      end
    end
  end
end
