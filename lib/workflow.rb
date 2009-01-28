require 'rubygems'
require 'active_support'

module Workflow
 
  class Specification
    
    attr_accessor :states, :initial_state, :meta, :on_transition_proc
    
    def initialize(meta = {}, &specification)
      @states = Hash.new
      @meta = meta
      instance_eval(&specification)
    end
    
    private
  
    def state(name, meta = {:meta => {}}, &events_and_etc)
      # meta[:meta] to keep the API consistent..., gah
      new_state = State.new(name, meta[:meta])
      @initial_state = new_state if @states.empty?
      @states[name.to_sym] = new_state
      @scoped_state = new_state
      instance_eval(&events_and_etc) if events_and_etc
    end
    
    def event(name, args = {}, &action)
      @scoped_state.events[name.to_sym] =
        Event.new(name, args[:transitions_to], (args[:meta] or {}), &action)
    end
    
    def on_entry(&proc)
      @scoped_state.on_entry = proc
    end
    
    def on_exit(&proc)
      @scoped_state.on_exit = proc
    end

    def on_transition(&proc)
      @on_transition_proc = proc
    end
  end
  
  class TransitionHalted < Exception

    attr_reader :halted_because

    def initialize(msg = nil)
      @halted_because = msg
      super msg
    end

  end

  class NoTransitionAllowed < Exception; end

  class State
    
    attr_accessor :name, :events, :meta, :on_entry, :on_exit
    
    def initialize(name, meta = {})
      @name, @events, @meta = name, Hash.new, meta
    end
    
    def to_s
      "#{name}"
    end

    def to_sym
      name.to_sym
    end
  end
  
  class Event
    
    attr_accessor :name, :transitions_to, :meta, :action
    
    def initialize(name, transitions_to, meta = {}, &action)
      @name, @transitions_to, @meta, @action = name, transitions_to.to_sym, meta, action
    end
    
  end
  
  module WorkflowClassMethods
    attr_reader :workflow_spec

    def workflow(&specification)
      @workflow_spec = Specification.new(Hash.new, &specification)
      @workflow_spec.states.values.each do |state|
        state_name = state.name
        module_eval do
          define_method "#{state_name}?" do
            state_name == current_state.name
          end
        end

        state.events.values.each do |event|
          event_name = event.name
          module_eval do
            define_method event_name do |*args|
              process_event!(event_name, *args)
            end
          end
        end
      end
    end
  end

  module WorkflowInstanceMethods
    def current_state 
      loaded_state = load_workflow_state
      res = spec.states[loaded_state.to_sym] if loaded_state
      res || spec.initial_state
    end

    def halted?
      @halted
    end

    def halted_because
      @halted_because
    end

    private

    def spec
      self.class.workflow_spec
    end

    def process_event!(name, *args)
      event = current_state.events[name.to_sym]
      raise NoTransitionAllowed.new(
        "There is no event #{name.to_sym} defined for the #{current_state} state") \
        if event.nil?
      @halted_because = nil
      @halted = false
      @raise_exception_on_halt = false
      # i don't think we've tested that the return value is
      # what the action returns... so yeah, test it, at some point.
      return_value = run_action(event.action, *args)
      if @halted
        if @raise_exception_on_halt
          raise TransitionHalted.new(@halted_because)
        else
          false
        end
      else
        run_on_transition(current_state, spec.states[event.transitions_to], name, *args)
        transition(current_state, spec.states[event.transitions_to], name, *args)
        return_value
      end
    end

    def halt(reason = nil)
      @halted_because = reason
      @halted = true
      @raise_exception_on_halt = false
    end

    def halt!(reason = nil)
      @halted_because = reason
      @halted = true
      @raise_exception_on_halt = true
    end

    def transition(from, to, name, *args)
      run_on_exit(from, to, name, *args)
      persist_workflow_state to.to_s
      run_on_entry(to, from, name, *args)
    end

    def run_on_transition(from, to, event, *args)
      instance_exec(from.name, to.name, event, *args, &spec.on_transition_proc) if spec.on_transition_proc
    end

    def run_action(action, *args)
      instance_exec(*args, &action) if action
    end

    def run_on_entry(state, prior_state, triggering_event, *args)     
      instance_exec(prior_state.name, triggering_event, *args, &state.on_entry) if state.on_entry
    end

    def run_on_exit(state, new_state, triggering_event, *args)
      instance_exec(new_state.name, triggering_event, *args, &state.on_exit) if state and state.on_exit
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
  end

  module ActiveRecordInstanceMethods
    # TODO: explain motivation
    def after_initialize_with_workflow_state_persistence
      write_attribute :workflow_state, current_state.to_s
    end

    def load_workflow_state
      read_attribute(:workflow_state)
    end

    # On transition the new workflow state is immediately saved in the
    # database.
    def persist_workflow_state(new_value)
      update_attribute :workflow_state, new_value
    end
  end

  def self.included(klass)
    klass.send :include, WorkflowInstanceMethods
    klass.extend WorkflowClassMethods
    if klass < ActiveRecord::Base
      klass.send :include, ActiveRecordInstanceMethods
    end
  end
end
