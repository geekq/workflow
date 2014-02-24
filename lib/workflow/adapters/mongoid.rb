module Workflow
  module Adapter
    module Mongoid
      module InstanceMethods
        def load_workflow_state
          send(self.class.workflow_column)
        end

        def persist_workflow_state(new_value)
          self.update_attribute(self.class.workflow_column, new_value)
        end

        private

        def write_initial_state
          send("#{self.class.workflow_column}=", current_state.to_s) if load_workflow_state.blank?
        end

      end
    end
  end
end
