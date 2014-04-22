module Workflow
  module Adapters
    module DataMapper
      module InstanceMethods
        def load_workflow_state
          send self.class.workflow_column
        end

        def persist_workflow_state(new_value)
          update self.class.workflow_column => new_value
        end

        private
        def write_initial_state
          write_attribute self.class.workflow_column, current_state.to_s
        end
      end
    end
  end
end