module Workflow
  # During transitions, an instance of this class can be found
  # on the object as `transition_context`.
  # Contains metadata related to the current transition underway.
  #
  # == To name parameters:
  #
  # During workflow definition, do the following:
  #
  #     before_transition :transition_handler
  #
  #     def transition_handler
  #       transition_context.name1 #  will equal 1
  #       transition_context.name2 #  will equal 2
  #       transition_context.name3 #  will equal 3
  #     end
  #
  #     workflow do
  #       event_args :name1, :name2, :name3
  #       state :foo do
  #         event :bar, transitions_to: :bax
  #       end
  #     end
  #
  # Then later call:
  #
  #     my_obj.submit! 1, 2, 3
  #
  # The entire list of passed parameters will still be available on +event_args+.
  # If you pass fewer parameters, the later ones will simply be nil.
  class TransitionContext
    attr_reader :from, :to, :event, :event_args, :attributes, :named_arguments
    def initialize(from:, to:, event:, event_args:, attributes:, named_arguments: [])
      @from = from
      @to = to
      @event = event
      @event_args = event_args
      @attributes = attributes
      @named_arguments = (named_arguments || []).zip(event_args).to_h
    end

    def values
      [from, to, event, event_args]
    end

    def method_missing(method, *args)
      if named_arguments.key?(method)
        named_arguments[method]
      else
        super
      end
    end
  end
end
