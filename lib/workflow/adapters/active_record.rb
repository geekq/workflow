module Workflow
  module Adapter
    module ActiveRecord
      def self.included(klass)
        klass.send :include, Adapter::ActiveRecord::InstanceMethods
        klass.send :extend, Adapter::ActiveRecord::Scopes
        klass.before_validation :write_initial_state
      end

      module InstanceMethods
        def load_workflow_state
          read_attribute(self.class.workflow_column)
        end

        # On transition the new workflow state is immediately saved in the
        # database.
        def persist_workflow_state(new_value)
          if self.class.validate_workflow_state_on_update
            old_state = self.send(self.class.workflow_column)
            # Use the last known saved value, if we've got ActiveModel::Dirty
            # mixed in - this allows forcing the workflow state with
            # self.workflow_state = ... and then triggering an event without
            # blowing up because we haven't been saved yet
            if self.respond_to?(:changed_attributes) && self.changed_attributes.has_key?(self.class.workflow_column)
              old_state = self.changed_attributes[self.class.workflow_column]
            end
            if self.class.unscoped.where(self.class.primary_key => self.id, self.class.workflow_column => old_state) \
                                  .update_all(self.class.workflow_column => new_value) == 0
              raise WorkflowStateHasChanged.new 'The workflow state has been changed since this object was (re)loaded'
            end
            self.send("#{self.class.workflow_column}=", new_value)
            self.changed_attributes.delete(self.class.workflow_column) if self.respond_to?(:changed_attributes)
          else
            # Rails 3.1 or newer
            update_column self.class.workflow_column, new_value
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

        attr_accessor :validate_workflow_state_on_update

        def workflow_with_scopes(options = {}, &specification)
          validate_on_update = options.delete(:validate_on_update) || false
          raise "Unexpected options: #{options}" unless options.empty?

          workflow_without_scopes(&specification)
          @validate_workflow_state_on_update = validate_on_update
          states = workflow_spec.states.values

          states.each do |state|
            define_singleton_method("with_#{state}_state") do
              where("#{table_name}.#{self.workflow_column.to_sym} = ?", state.to_s)
            end
          end
        end
      end
    end
  end
end
