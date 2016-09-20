require 'rubygems'
require 'active_support/concern'
require 'workflow/version'
require 'workflow/specification'
require 'workflow/callbacks'
require 'workflow/adapters/active_record'
require 'workflow/adapters/remodel'
require 'workflow/adapters/active_record_validations'
require 'workflow/transition_context'

# See also README.markdown for documentation
module Workflow
  # @!parse include Callbacks
  # @!parse extend Callbacks::ClassMethods

  extend ActiveSupport::Concern
  include Callbacks
  include Errors

  included do

    # Look for a hook; otherwise detect based on ancestor class.
    if respond_to?(:workflow_adapter)
      include self.workflow_adapter
    else
      if Object.const_defined?(:ActiveRecord) && self < ActiveRecord::Base
        include Adapter::ActiveRecord
        include Adapter::ActiveRecordValidations
      end
      if Object.const_defined?(:Remodel) && klass < Adapter::Remodel::Entity
        include Adapter::Remodel::InstanceMethods
      end
    end
  end

  # Returns a state object representing the current workflow state.
  #
  # @return [State] Current workflow state
  def current_state
    loaded_state = load_workflow_state
    res = workflow_spec.states[loaded_state.to_sym] if loaded_state
    res || workflow_spec.initial_state
  end

  # Deprecated.  Check for false return value from {#process_event!}
  # @return true if the last transition was halted by one of the transition callbacks.
  def halted?
    @halted
  end

  # Returns the reason given to a call to {#halt} or {#halt!}, if any.
  # @return [String] The reason the transition was aborted.
  attr_reader :halted_because

  # Initiates state transition via the named event
  #
  # @param [Symbol] name name of event to initiate
  # @param [Mixed] *args Arguments passed to state transition. Available also to callbacks
  # @return [Type] description of returned object
  def process_event!(name, *args)
    event = current_state.events.first_applicable(name, self)
    raise NoTransitionAllowed.new(
      "There is no event #{name.to_sym} defined for the #{current_state} state") \
      if event.nil?
    @halted_because = nil
    @halted = false

    check_transition(event)

    from = current_state
    to = workflow_spec.states[event.transitions_to]
    execute_transition!(from, to, name, event, *args)
  end


  # Stop the current transition and set the reason for the abort.
  #
  # @param optional [String] reason Reason for halting transition.
  # @return [void]
  def halt(reason = nil)
    @halted_because = reason
    @halted = true
    throw :abort
  end

  # Sets halt reason and raises [TransitionHaltedError] error.
  #
  # @param optional [String] reason Reason for halting
  # @return [void]
  def halt!(reason = nil)
    @halted_because = reason
    @halted = true
    raise TransitionHaltedError.new(reason)
  end

  #   The specification for this object.
  #   Could be set on a singleton for the object, on the object's class,
  #   Or else on a superclass of the object.
  # @return [Specification] The Specification that applies to this object.
  def workflow_spec
    # check the singleton class first
    class << self
      return workflow_spec if workflow_spec
    end

    c = self.class
    # using a simple loop instead of class_inheritable_accessor to avoid
    # dependency on Rails' ActiveSupport
    until c.workflow_spec || !(c.include? Workflow)
      c = c.superclass
    end
    c.workflow_spec
  end

  private

  def has_callback?(action)
    # 1. public callback method or
    # 2. protected method somewhere in the class hierarchy or
    # 3. private in the immediate class (parent classes ignored)
    action = action.to_sym
    self.respond_to?(action) or
      self.class.protected_method_defined?(action) or
      self.private_methods(false).map(&:to_sym).include?(action)
  end

  def run_action_callback(action_name, *args)
    action = action_name.to_sym
    if has_callback?(action)
      meth = method(action)
      check_method_arity! meth, *args
      meth.call *args
    end
  end

  def check_method_arity!(method, *args)
    arity = method.arity

    unless (arity >= 0 && args.length == arity) || (arity < 0 && (args.length + 1) >= arity.abs)
      raise CallbackArityError.new("Method #{method.name} has arity #{arity} but was called with #{args.length} arguments.")
    end
  end

  def check_transition(event)
    # Create a meaningful error message instead of
    # "undefined method `on_entry' for nil:NilClass"
    # Reported by Kyle Burton
    if !workflow_spec.states[event.transitions_to]
      raise WorkflowError.new("Event[#{event.name}]'s " +
          "transitions_to[#{event.transitions_to}] is not a declared state.")
    end
  end


  # load_workflow_state and persist_workflow_state
  # can be overriden to handle the persistence of the workflow state.
  #
  # Default (non ActiveRecord) implementation stores the current state
  # in a variable.
  #
  # Default ActiveRecord implementation uses a 'workflow_state' database column.
  def load_workflow_state
    @workflow_state if instance_variable_defined? :@workflow_state
  end

  def persist_workflow_state(new_value)
    @workflow_state = new_value
  end

  module ClassMethods
    attr_reader :workflow_spec

    # Instructs Workflow which column to use to persist workflow state.
    #
    # @param optional [Symbol] column_name name of column on table
    # @return [void]
    def workflow_column(column_name=nil)
      if column_name
        @workflow_state_column_name = column_name.to_sym
      end
      if !instance_variable_defined?('@workflow_state_column_name') && superclass.respond_to?(:workflow_column)
        @workflow_state_column_name = superclass.workflow_column
      end
      @workflow_state_column_name ||= :workflow_state
    end


    ##
    # Define workflow for the class.
    #
    # @yield [] Specification of workflow. Example below and in README.markdown
    # @return [nil]
    #
    # Workflow definition takes place inside the yielded block.
    # @see Specification::state
    # @see Specification::event
    #
    # ~~~ruby
    #
    # class Article
    #   include Workflow
    #   workflow do
    #     state :new do
    #       event :submit, :transitions_to => :awaiting_review
    #     end
    #     state :awaiting_review do
    #       event :review, :transitions_to => :being_reviewed
    #     end
    #     state :being_reviewed do
    #       event :accept, :transitions_to => :accepted
    #       event :reject, :transitions_to => :rejected
    #     end
    #     state :accepted
    #     state :rejected
    #   end
    # end
    #
    #~~~
    #
    def workflow(&specification)
      assign_workflow Specification.new(Hash.new, &specification)
    end

    private

    # Creates the convinience methods like `my_transition!`
    def assign_workflow(specification_object)
      # Merging two workflow specifications can **not** be done automically, so
      # just make the latest specification win. Same for inheritance -
      # definition in the subclass wins.
      if self.superclass.respond_to?(:workflow_spec, true) && self.superclass.workflow_spec
        undefine_methods_defined_by_workflow_spec superclass.workflow_spec
      end

      @workflow_spec = specification_object
      @workflow_spec.states.values.each do |state|
        state_name = state.name
        module_eval do
          define_method "#{state_name}?" do
            state_name == current_state.name
          end
        end

        state.events.flat.each do |event|
          event_name = event.name
          module_eval do
            define_method "#{event_name}!".to_sym do |*args|
              process_event!(event_name, *args)
            end

            define_method "can_#{event_name}?" do
              return !!current_state.events.first_applicable(event_name, self)
            end
          end
        end
      end
    end

    def undefine_methods_defined_by_workflow_spec(inherited_workflow_spec)
      inherited_workflow_spec.states.values.each do |state|
        state_name = state.name
        module_eval do
          undef_method "#{state_name}?"
        end

        state.events.flat.each do |event|
          event_name = event.name
          module_eval do
            undef_method "#{event_name}!".to_sym
            undef_method "can_#{event_name}?"
          end
        end
      end
    end
  end
end
