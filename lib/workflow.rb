require 'rubygems'
require 'active_support'

module Workflow
 
  class Specification
    
    attr_accessor :states, :initial_state, :meta, :on_transition
    
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
  end
  
  class TransitionHalted < Exception

    attr_reader :halted_because

    def initialize(msg = nil)
      @halted_because = msg
      super msg
    end

  end

  class State
    
    attr_accessor :name, :events, :meta, :on_entry, :on_exit
    
    def initialize(name, meta = {})
      @name, @events, @meta = name, Hash.new, meta
    end
    
    def to_s
      "#{name}"
    end
  end
  
  class Event
    
    attr_accessor :name, :transitions_to, :meta, :action
    
    def initialize(name, transitions_to, meta = {}, &action)
      @name, @transitions_to, @meta, @action = name, transitions_to.to_sym, meta, action
    end
    
  end
  
  module ActiveRecordClassMethods
    attr_reader :workflow_spec

    def workflow(&specification)
      @workflow_spec = Specification.new(Hash.new, &specification)
      @workflow_spec.states.values.each do |state|
        state.events.values.each do |event|
          module_eval do
            define_method event.name do |*args|
              process_event!(event.name, *args)
            end
          end
        end
      end
    end

  end

  module ActiveRecordInstanceMethods
    #    alias_method :initialize_before_workflow, :initialize
    #    attr_accessor :workflow
    #    def initialize(attributes = nil)
    #      initialize_before_workflow(attributes)
    #      @workflow = Workflow.new(self.class)
    #      @workflow.bind_to(self)
    #    end
    #    def after_find
    #      @workflow = if workflow_state.nil?
    #        Workflow.new(self.class)
    #      else
    #        Workflow.reconstitute(workflow_state.to_sym, self.class)
    #      end
    #      @workflow.bind_to(self)
    #    end
    #    alias_method :before_save_before_workflow, :before_save
    #    def before_save
    #      before_save_before_workflow
    #      self.workflow_state = @workflow.state.to_s
    #    end
    def current_state
      spec.states[read_attribute(:workflow_state).to_sym]
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
      update_attribute :workflow_state, to.to_s
      run_on_entry(to, from, name, *args)
    end

    def run_on_transition(from, to, event, *args)
      context.instance_exec(from.name, to.name, event, *args, &spec.on_transition) if spec.on_transition
    end

    def run_action(action, *args)
      context.instance_exec(*args, &action) if action
    end

    def run_on_entry(state, prior_state, triggering_event, *args)
      if state.on_entry
        context.instance_exec(prior_state.name, triggering_event, *args, &state.on_entry)
      end
    end

    def run_on_exit(state, new_state, triggering_event, *args)
      if state and state.on_exit
        context.instance_exec(new_state.name, triggering_event, *args, &state.on_exit)
      end
    end
  end

  module NonActiveRecordClassMethods
    #    alias_method :initialize_before_workflow, :initialize
    #    attr_reader :workflow
    #    def initialize(*args, &block)
    #      initialize_before_workflow(*args, &block)
    #      @workflow = Workflow.new(self.class)
    #      @workflow.bind_to(self)
    #    end
  end

  def self.included(klass)
    puts "Included in #{klass}"
    if klass < ActiveRecord::Base
      puts "EXTENDING"
      klass.send :attr_accessor, :workflow
      klass.send :include, ActiveRecordInstanceMethods
      klass.extend ActiveRecordClassMethods
    end
  end

end
