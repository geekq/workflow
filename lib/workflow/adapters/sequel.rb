module Workflow
  module Adapter
    module Sequel
      module InstanceMethods
        def load_workflow_state
          send(self.class.workflow_column)
        end

        # On transition the new workflow state is immediately saved in the
        # database.
        def persist_workflow_state(new_value)
          if self.respond_to? :update
            update(self.class.workflow_column => new_value)
          end
        end

        def before_save
          write_initial_state
          super
        end

        private
        # Motivation: even if NULL is stored in the workflow_state database column,
        # the current_state is correctly recognized in the Ruby code. The problem
        # arises when you want to SELECT records filtering by the value of initial
        # state. That's why it is important to save the string with the name of the
        # initial state in all the new records.
        def write_initial_state
          send("#{self.class.workflow_column}=".to_sym, current_state.to_s)
        end
      end
    end
  end
end
