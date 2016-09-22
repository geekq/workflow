module Workflow
  module Errors
    class TransitionHaltedError < StandardError

      attr_reader :halted_because

      def initialize(msg = nil)
        @halted_because = msg
        super msg
      end

    end

    class NoMatchingTransitionError < StandardError
    end

    class NoTransitionAllowed < StandardError
    end

    class WorkflowError < StandardError
    end

    class CallbackArityError < StandardError
    end

    class WorkflowDefinitionError < StandardError
    end
  end
end
