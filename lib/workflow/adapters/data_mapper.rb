module Workflow
  module DataMapper
    def load_workflow_state
      self[:state]
    end

    def persist_workflow_state(new_value)
      self[:state] = new_value
      save!
    end
  end
end