module Workflow
  class TransitionHalted < StandardError

    attr_reader :halted_because

    def initialize(msg = nil)
      @halted_because = msg
      super msg
    end

  end

  class NoTransitionAllowed < StandardError; end

  class WorkflowError < StandardError; end

  class WorkflowDefinitionError < StandardError; end
end
