module Workflow
  module Adapter
    module ActiveRecord
      module InstanceMethods
        def load_workflow_state
          read_attribute(self.class.workflow_column)
        end

        # On transition the new workflow state is immediately saved in the
        # database.
        def persist_workflow_state(new_value)
          if self.respond_to? :update_column
            # Rails 3.1 or newer
            update_column self.class.workflow_column, new_value
          else
            # older Rails; beware of side effect: other (pending) attribute changes will be persisted too
            update_attribute self.class.workflow_column, new_value
          end
        end

        private

        # Motivation: even if NULL is stored in the workflow_state database column,
        # the current_state is correctly recognized in the Ruby code. The problem
        # arises when you want to SELECT records filtering by the value of initial
        # state. That's why it is important to save the string with the name of the
        # initial state in all the new records.
        def write_initial_state
          write_attribute self.class.workflow_column, current_state.to_s
        end
      end

      # This module will automatically generate ActiveRecord scopes based on workflow states.
      # The name of each generated scope will be something like `with_<state_name>_state`
      #
      # Examples:
      #
      # Article.with_pending_state # => ActiveRecord::Relation
      #
      # Example above just adds `where(:state_column_name => 'pending')` to AR query and returns
      # ActiveRecord::Relation.
      module Scopes
        def self.extended(object)
          class << object
            alias_method :workflow_without_scopes, :workflow unless method_defined?(:workflow_without_scopes)
            alias_method :workflow, :workflow_with_scopes
          end
        end

        def workflow_with_scopes(&specification)
          workflow_without_scopes(&specification)
          states     = workflow_spec.states.values
          eigenclass = class << self; self; end

          states.each do |state|
            # Use eigenclass instead of `define_singleton_method`
            # to be compatible with Ruby 1.8+
            eigenclass.send(:define_method, "with_#{state}_state") do
              where("#{table_name}.#{self.workflow_column.to_sym} = ?", state.to_s)
            end
          end
        end
      end
    end
  end
end
