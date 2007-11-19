%w(rubygems active_support).each { |f| require f }

module StateMachine

  @@specifications = {}

  class << self
    
    def specify(name = :default, &specification)
      @@specifications[name] = Specification.new(&specification)
    end
    
    def new(name = :default)
      @@specifications[name].to_machine
    end
    
    def reconstitute(reconstitute_at = nil, name = :default)
      @@specifications[name].to_machine(reconstitute_at)
    end
    
  end
  
  class Specification
    
    attr_accessor :states, :on_transition
    
    def initialize(&specification)
      self.states = []
      instance_eval(&specification)
    end
    
    def to_machine(reconstitute_at = nil)
      Machine.new(states, @on_transition, reconstitute_at)
    end
    
  private
  
    def state(name, &events_and_etc)
      self.states << State.new(name)
      instance_eval(&events_and_etc) if events_and_etc
    end
    
    def on_transition(&proc)
      @on_transition = proc
    end
    
    def event(name, args = {}, &action)
      scoped_state.events << Event.new(name, args, &action)
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
  
  class Machine
    
    attr_accessor :states, :current_state, :on_transition
    
    def initialize(states, on_transition, reconstitute_at = nil)
      self.states, self.on_transition = states, on_transition
      if reconstitute_at.nil?
        transition(nil, states.first, nil)
      else
        self.current_state = find_state_by_name(reconstitute_at)
      end
    end
    
    def find_state_by_name(name)
      states.detect { |s| s.name == name }
    end
    
    def method_missing(name, *args)
      if current_state.has_event?(name)
        process_event!(name, *args)
      else
        super
      end
    end
    
  private
    
    def process_event!(name, *args)
      event = current_state.find_event_by_name(name)
      run_on_transition(current_state, find_state_by_name(event.transitions_to), name, *args)
      transition(current_state, find_state_by_name(event.transitions_to), name, *args)
      run_action(event.action, *args)
    end
    
    def transition(from, to, name, *args)
      run_on_exit(from, to, name, *args)
      self.current_state = to
      run_on_entry(to, from, name, *args)
    end
    
    def run_on_transition(from, to, event, *args)
      instance_exec(from, to, event, *args, &on_transition) if on_transition
    end
    
    def run_action(action, *args)
      instance_exec(*args, &action) if action
    end
    
    def run_on_entry(state, prior_state, triggering_event, *args)
      if state.on_entry
        instance_exec(prior_state, triggering_event, *args, &state.on_entry)
      end
    end
    
    def run_on_exit(state, new_state, triggering_event, *args)
      if state and state.on_exit
        instance_exec(new_state, triggering_event, *args, &state.on_exit)
      end
    end
    
  end
  
  class State
    
    attr_accessor :name, :events, :on_entry, :on_exit
    
    def initialize(name)
      @name, @events = name, []
    end
    
    def has_event?(name)
      !!find_event_by_name(name)
    end
    
    def find_event_by_name(name)
      events.detect { |e| e.name == name }
    end
    
  end
  
  class Event
    
    attr_accessor :name, :transitions_to, :action
    
    def initialize(name, args, &action)
      @name, @transitions_to, @action = name, args[:transitions_to], action
    end
    
  end

end