module Workflow
  module Adapter
    module Sequel
      def self.included(klass)
        klass.send :include, InstanceMethods
      end

      module InstanceMethods
        def load_workflow_state
          send(self.class.workflow_column)
        end

        def persist_workflow_state(new_value)
          send("#{self.class.workflow_column}=", new_value)
          save(changed: true, columns: [self.class.workflow_column], validate: false)
        end

        def before_validation
          send("#{self.class.workflow_column}=", current_state.to_s) unless send(self.class.workflow_column)
          super
        end
      end
    end
  end
end
