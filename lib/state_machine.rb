module StateMachine

  @@specifications = {}

  class << self
    
    def specify(name = :default, &description)
      @@specifications[name] = Specifier.new(&description).to_specification
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
    
    def initialize(&description)
      instance_eval(&description)
    end
    
    def state(name)
      (@states ||= []) << name
    end
    
    def initial_state(name)
      @initial_state = name
    end
    
    def to_specification
      spec = Specification.new
      spec.states = @states
      spec.initial_state = @initial_state
      spec
    end
    
  end
  
  # describes a Machine and how it should work, can validate itself
  class Specification
    attr_accessor :states, :initial_state
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
    
  end
  
  # do we need classes for Actions/Events/Transitions/Etc? Perhaps
  # in specification?
  
  # don't forget the bind-mode, the ability to plug in to
  # another object and merge w/ it's API

end