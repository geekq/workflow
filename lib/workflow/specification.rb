require 'workflow/state'
require 'workflow/event'
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
      spec.states.each do |state|
        state.events.reject{ |e|
          e.name.to_s =~ /^revert_/
        }.select{|e| e.transitions.length == 1}.each do |event|
          revert_event_name = "revert_#{event.name}".to_sym
          from_state_for_revert = event.transitions.first.target_state
          from_state_for_revert.on revert_event_name, to: state
        end
      end
    end

    set_callback(:spec_definition, :after) do |spec|
      spec.states.each do |state|
        state.events.each do |event|
          event.transitions.each do |transition|
            target_state = spec.find_state(transition.target_state)
            unless target_state.present?
              raise Workflow::Errors::WorkflowDefinitionError.new("Event #{event.name} transitions to #{transition.target_state} but there is no such state.")
            end
            transition.target_state = target_state
          end
        end
      end
    end

    def find_state(name)
      states.find{|t| t.name == name.to_sym}
    end




    # @api private
    #
    # @param [Hash] meta Metadata
    # @yield [] Block for workflow definition
    # @return [Specification]
    def initialize(meta = {}, &specification)
      @states = []
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
      name = name.to_sym
      new_state = Workflow::State.new(name, self, meta)
      @initial_state ||= new_state
      @states << new_state
      new_state.instance_eval(&events) if block_given?
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
