module Workflow
  class State
    include Comparable

    attr_accessor :name, :events, :meta, :on_entry, :on_exit
    attr_reader :sequence

    def initialize(name, sequence, **meta)
      @name, @sequence, @events, @meta = name.to_sym, sequence, [], meta
    end

    def find_event(name)
      events.find{|t| t.name == name}
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
    #    on :review, to: :being_reviewed
    #
    #    on :submit do
    #      to :submitted,
    #        if:     [ "name == 'The Dude'", :abides?, -> (rug) {rug.tied_the_room_together?}],
    #        unless: :nihilist?
    #
    #      to :trash, unless: :body?
    #      to :another_place do |article|
    #        article.foo?
    #      end
    #   end
    # end
    #
    #  state :kitchen
    #  state :the_bar
    #  state :the_diner
    #end
    #```
    def on(name, to: nil, meta: nil, &transitions)
      if to && block_given?
        raise Errors::WorkflowDefinitionError.new("Event target can only be received in the method call or the block, not both.")
      end

      unless to || block_given?
        raise Errors::WorkflowDefinitionError.new("No event target given for event #{name}")
      end

      if find_event(name)
        raise Errors::WorkflowDefinitionError.new("Already defined an event [#{name}] for state[#{self.name}]")
      end

      event = Workflow::Event.new(name, meta)

      if to
        event.to to
      else
        event.instance_eval(&transitions)
      end

      if event.transitions.empty?
        raise Errors::WorkflowDefinitionError.new("No transitions defined for event [#{name}] on state [#{self.name}]")
      end

      events << event
      nil
    end

    def inspect
      "<State name=#{name.inspect} events(#{events.length})=#{events.inspect}>"
    end

    def <=>(other_state)
      unless other_state.is_a?(State)
        raise StandardError.new "Other State #{other_state} is a #{other_state.class}.  I can only be compared with a Workflow::State."
      end
      self.sequence <=> other_state.sequence
    end
  end
end
