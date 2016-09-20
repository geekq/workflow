module Workflow
  class State
    attr_accessor :name, :events, :meta, :on_entry, :on_exit
    attr_reader :spec

    def initialize(name, spec, meta = {})
      @name, @spec, @events, @meta = name.to_sym, spec, {}, meta
    end

    def select_event(name, entity)
      events.fetch(name, []).find do |event|
        event.conditions_apply?(entity)
      end
    end

    def uniq_events
      events.values.flatten.uniq do |event|
        [event.name, event.transitions_to, event.meta]
      end
    end

    # Define an event on this specification.
    # Must be called within the scope of the block within a call to {#state}.
    #
    # @param [Symbol] name The name of the event
    # @param [Hash] args
    # @option args [Symbol] :transitions_to The state this event transitions to.
    # @option args [Symbol] :if optional instance method name or [Proc] that will receive the object when called.
    # @option args [Hash] :meta Optional metadata to be stored on the event object
    # @return [nil]
    #
    #```ruby
    #workflow do
    #  state :new do
    #    event :foo, transitions_to: :next_state
    #    # If event `bar` is called for, the first transition with a matching condition will be executed.
    #    #   An error will be raised of no transition is currently allowable by that name.
    #    event :bar, if: :bar_is_ready?, transitions_to: :the_bar
    #    event :bar, if: -> (obj) {obj.is_okay?}, transitions_to: :the_bazzle
    #  end
    #
    #  state :next_state
    #  state :the_bar
    #  state :the_bazzle
    #end
    #```
    def event(name, args = {})
      target = args[:transitions_to] || args[:transition_to]
      condition = args[:if]
      raise WorkflowDefinitionError.new(
        "missing ':transitions_to' in workflow event definition for '#{name}'") \
        if target.nil?

      (events[name] ||= []) << Workflow::Event.new(name, target, condition, (args[:meta] || {}))
    end

    if RUBY_VERSION >= '1.9'
      include Comparable
      def <=>(other_state)
        raise ArgumentError, "state `#{other_state.name}' does not exist" unless spec.states.include?(other_state)
        spec.states.index(self) <=> spec.states.index(other_state)
      end
    end
  end
end
