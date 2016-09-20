require 'workflow/state'
require 'workflow/event'
require 'workflow/event_collection'
require 'workflow/errors'
require 'active_support/callbacks'

module Workflow
  # Metadata object describing available states and state transitions.
  class Specification
    include ActiveSupport::Callbacks

    # The state objects defined for this specification, keyed by name
    # @return [Hash]
    attr_reader :states

    # State object to be given to newly created objects under this workflow.
    # @return [State]
    attr_reader :initial_state

    # Optional metadata stored with this workflow specification
    # @return [Hash]
    attr_reader :meta

    # List of symbols, for attribute accessors to be added to {TransitionContext} object
    # @return [Array]
    attr_reader :named_arguments

    define_callbacks :spec_definition

    set_callback(:spec_definition, :after, if: :define_revert_events?) do |spec|
      spec.states.keys.each do |state_name|
        state = spec.states[state_name]

        state.events.flat.reject{|e| e.name.to_s =~ /^revert_/ }.each do |event|
          revert_event_name = "revert_#{event.name}"
          revert_event = Workflow::Event.new(revert_event_name, state)
          from_state_for_revert = spec.states[event.transitions_to.to_sym]
          from_state_for_revert.events.push revert_event_name, revert_event
        end
      end
    end

    # @api private
    #
    # @param [Hash] meta Metadata
    # @yield [] Block for workflow definition
    # @return [Specification]
    def initialize(meta = {}, &specification)
      @states = Hash.new
      @meta = meta
      run_callbacks :spec_definition do
        instance_eval(&specification)
      end
    end

    # Define a new state named [name]
    #
    # @param [Symbol] name name of state
    # @param [Hash] meta Metadata to be stored with the state within the {Specification} object
    # @yield [] block defining events for this state.
    # @return [nil]
    def state(name, meta: {}, &events)
      new_state = Workflow::State.new(name, self, meta)
      @initial_state ||= new_state
      @states[name.to_sym] = new_state
      @scoped_state = new_state
      instance_eval(&events) if block_given?
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
      @scoped_state.add_event name,
        Workflow::Event.new(name, target, condition, (args[:meta] || {}))
    end


    # Specify attributes to make available on the {TransitionContext} object
    # during transitions taking place in this specification.
    # The attributes' values will be taken in order from the arguments passed to
    # the event transit method call.
    #
    # @param [Array] names A list of symbols
    # @return [nil]
    def event_args(*names)
      @named_arguments = names
    end


    # Also create additional event transitions that will move each configured transition
    # in the reverse direction.
    #
    # @return [nil]
    #
    #```ruby
    # class Article
    #   include Workflow
    #   workflow do
    #     define_revert_events!
    #     state :foo do
    #       event :bar, transitions_to: :bax
    #     end
    #     state :bax
    #   end
    # end
    #
    # a = Article.new
    # a.process_event! :foo
    # a.current_state.name          # => :bax
    # a.process_event! :revert_bar
    # a.current_state.name          # => :foo
    #```
    def define_revert_events!
      @define_revert_events = true
    end

    private


    def define_revert_events?
      !!@define_revert_events
    end

  end
end
