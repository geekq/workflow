module Workflow
  # Used during 
  class TransitionContext
    attr_reader :from, :to, :event, :event_args
    def initialize(from:, to:, event:, event_args:)
      @from = from
      @to = to
      @event = event
      @event_args = event_args
    end

    def values
      [from, to, event, event_args]
    end
  end
end
