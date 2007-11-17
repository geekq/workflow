module StateMachine

  @@specifications = {}

  class << self
    
    def specify(name = :default, &states)
      @@specifications[name] = Specifier.new(&states).to_specification
    end
    
    def new(name = :default)
      Machine.new(@@specifications[name])
    end
    
    # def reconstitute(name = :default, at_state = :default)
    #   Machine.reconstitute(@@specifications[name], at_state)
    # end
    
  end
  
private
  
  # implements the metaprogramming API for creating Specifications
  class Specifier
    
    def initialize(&states)
      instance_eval(&states)
    end
    
    def state(name, &events)
      (@states ||= []) << name
      instance_eval(&events) if events
    end
    
    def event(name, config = {})
      (@events ||= {}; @events[@states.last] ||= []) << name
      @config ||= {}
      @config["#{@states.last}#{name}"] = config
    end
    
    def action(name, &proc)
      @actions ||= {}
      @actions[name] = proc
    end
    
    def initial_state(name)
      @initial_state = name
    end
    
    def to_specification
      Specification.new(@states, @events, @initial_state, @config, @actions)
    end
    
  end
  
  # describes a Machine and how it should work, can validate itself
  class Specification
    attr_reader :states, :initial_state
    def initialize(states, events, initial_state, config, actions)
      @states, @events, @initial_state = states, events, initial_state
      @config, @actions = config, actions
    end
    def events_for_state(state)
      @events[state]
    end
    def config_for_event_in_state(state, event)
      @config["#{state}#{event}"]
    end
    def action(name)
      @actions[name]
    end
  end
  
  # an instance of an actual machine, implementing the rest?
  class Machine
    
    def initialize(specification)
      @specification = specification
      @current_state = specification.initial_state
    end
    
    def states
      @specification.states
    end
    
    def current_state
      @current_state
    end
    
    def events_for_state(state)
      @specification.events_for_state(state)
    end
    
    def method_missing(event, *args, &block)
      if events_for_state(current_state).include?(event)
        config = @specification.config_for_event_in_state(current_state, event)
        @current_state = config[:transition_to]
        if config[:trigger]
          if config[:trigger].is_a? Array
            config[:trigger].each { |n| instance_eval &@specification.action(n) }
          else
            instance_eval &@specification.action(config[:trigger])
          end
        end 
      else
        raise Exceptions::InvalidEvent.new("#{event.inspect} is an invalid event for state #{current_state.inspect}, did you mean one of #{events_for_state(current_state).inspect}?")
      end
    end
    
  end
  
  module Exceptions
    
    class InvalidEvent < Exception
    end
    
  end
  
  # do we need classes for Actions/Events/Transitions/Etc? Perhaps
  # in specification?
  
  # don't forget the bind-mode, the ability to plug in to
  # another object and merge w/ it's API

end