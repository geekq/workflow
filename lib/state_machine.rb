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
  
  # implements the metaprogramming API for creating Specifications
  class Specifier
    def initialize(&description)
    end
    def to_specification
      Specification.new
    end
  end
  
  # describes a Machine and how it should work, can validate itself
  class Specification
    def initialize
    end
  end
  
  # an instance of an actual machine, implementing the rest?
  class Machine
    def initialize(specification)
      @specification = specification
    end
    def states
      [:new, :used, :broken]
    end
  end
  
  # do we need classes for Actions/Events/Transitions/Etc? Perhaps
  # in specification?
  
  # don't forget the bind-mode, the ability to plug in to
  # another object and merge w/ it's API

end