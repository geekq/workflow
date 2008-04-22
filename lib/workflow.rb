%w(rubygems active_support).each { |f| require f }

module Workflow

  @@specifications = {}

  class << self
    
    def specify(name = :default, meta = {:meta => {}}, &specification)
      @@specifications[name] = Specification.new(meta[:meta], &specification)
    end
    
    def new(name = :default, args = {})
      @@specifications[name].to_instance(args[:reconstitute_at])
    end
    
    def reconstitute(reconstitute_at = nil, name = :default)
      @@specifications[name].to_instance(reconstitute_at)
    end
    
    def append_features(receiver)
      receiver.instance_eval do
        def workflow(&specification)
          Workflow.specify(self, &specification)
        end
      end
      receiver.class_eval do
        alias_method :initialize_before_workflow, :initialize
        attr_reader :workflow
        def initialize(*args, &block)
          initialize_before_workflow(*args, &block)
          @workflow = Workflow.new(self.class)
          @workflow.bind_to(self)
        end
      end
    end
    
  end
  
  class Specification
    
    attr_accessor :states, :meta, :on_transition
    
    def initialize(meta = {}, &specification)
      @states = []
      @meta = meta
      instance_eval(&specification)
    end
    
    def to_instance(reconstitute_at = nil)
      Instance.new(states, @on_transition, @meta, reconstitute_at)
    end
    
  private
  
    def state(name, meta = {:meta => {}}, &events_and_etc)
      # meta[:meta] to keep the API consistent..., gah
      self.states << State.new(name, meta[:meta])
      instance_eval(&events_and_etc) if events_and_etc
    end
    
    def on_transition(&proc)
      @on_transition = proc
    end
    
    def event(name, args = {}, &action)
      scoped_state.add_event Event.new(name, args[:transitions_to], (args[:meta] or {}), &action)
    end
    
    def on_entry(&proc)
      scoped_state.on_entry = proc
    end
    
    def on_exit(&proc)
      scoped_state.on_exit = proc
    end
    
    def scoped_state
      states.last
    end
    
  end
  
  class Instance
    
    class TransitionHalted < Exception

      attr_reader :halted_because

      def initialize(msg = nil)
        @halted_because = msg
        super msg
      end

    end
    
    attr_accessor :states, :meta, :current_state, :on_transition, :context
    
    def initialize(states, on_transition, meta = {}, reconstitute_at = nil)
      @states, @on_transition, @meta = states, on_transition, meta
      @context = self
      if reconstitute_at.nil?
        transition(nil, states.first, nil)
      else
        self.current_state = states(reconstitute_at)
      end
    end
    
    def state(fetch = nil)
      if fetch
        states(fetch)
      else
        current_state.name
      end
    end
    
    def states(name = nil)
      if name
        @states.detect { |s| s.name == name }
      else
        @states.collect { |s| s.name }
      end
    end
    
    def method_missing(name, *args)
      if current_state.events(name)
        process_event!(name, *args)
      elsif name.to_s[-1].chr == '?' and states(name.to_s[0..-2].to_sym)
        current_state == states(name.to_s[0..-2].to_sym)
      else
        super
      end
    end
    
    def bind_to(another_context)
      self.context = another_context
      patch_context(another_context) if another_context != self
    end
    
    def halted?
      @halted
    end
    
    def halted_because
      @halted_because
    end
    
  private
  
    def patch_context(context)
      context.instance_variable_set("@workflow", self)
      context.instance_eval do
        alias :method_missing_before_workflow :method_missing
        #
        # PROBLEM: method_missing in on_transition events
        # when bound to other context is raising confusing
        # error messages, so need to rethink how this is
        # implemented - i.e. should we just check that an
        # event exists rather than send ANY message to the
        # machine? so like:
        #
        # if @workflow.state.events(ref_to_sym)
        #   execute
        # else
        #   super ?
        # end
        #
        def method_missing(method, *args)
          @workflow.send(method, *args)
        rescue NoMethodError
          method_missing_before_workflow(method, *args)
        end
      end
    end
    
    def process_event!(name, *args)
      event = current_state.events(name)
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
        run_on_transition(current_state, states(event.transitions_to), name, *args)
        transition(current_state, states(event.transitions_to), name, *args)
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
      self.current_state = to
      run_on_entry(to, from, name, *args)
    end
    
    def run_on_transition(from, to, event, *args)
      context.instance_exec(from.name, to.name, event, *args, &on_transition) if on_transition
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
  
  class State
    
    attr_accessor :name, :events, :meta, :on_entry, :on_exit
    
    def initialize(name, meta = {})
      @name, @events, @meta = name, [], meta
    end
    
    def events(name = nil)
      if name
        @events.detect { |e| e.name == name }
      else
        @events.collect { |e| e.name }
      end
    end
    
    def add_event(event)
      @events << event
    end
    
  end
  
  class Event
    
    attr_accessor :name, :transitions_to, :meta, :action
    
    def initialize(name, transitions_to, meta = {}, &action)
      @name, @transitions_to, @meta, @action = name, transitions_to, meta, action
    end
    
  end
  
end