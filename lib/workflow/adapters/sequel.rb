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

        def before_create
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
      module Subsets
        def self.extended(object)
          class << object
            alias_method :workflow_without_subsets, :workflow unless method_defined?(:workflow_without_subsets)
            alias_method :workflow, :workflow_with_subsets
          end
        end

        def workflow_with_subsets(&specification)
          workflow_without_subsets(&specification)
          states     = workflow_spec.states.values
          eigenclass = class << self; self; end

          states.each do |state|
            # Use eigenclass instead of `define_singleton_method`
            # to be compatible with Ruby 1.8+
            eigenclass.send(:define_method, "in_#{state}_state") do
              where("#{table_name}.#{self.workflow_column.to_sym} = ?", state.to_s)
            end
          end
        end
      end
    end
  end
end
