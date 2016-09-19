require 'active_support/concern'

module Workflow
  module Adapter
    module ActiveRecordValidations
      extend ActiveSupport::Concern

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

      ###
      #
      # Captures instance method calls of the form `:transitioning_from_<state_name>`
      #   and `:transitioning_to_<state_name>`.
      #
      # For use with validators, e.g. `validates :foobar, presence: true, if: :transitioning_to_some_state?`
      #
      def method_missing(method, *args, &block)
        if method.to_s =~ /^transitioning_(from|to|via_event)_([\w_-]+)\?$/
          class_eval "
          def #{method}
            transitioning? direction: '#{$~[1]}', state: '#{$~[2]}'
          end
          "
          send method
        else
          super
        end
      end

      # def valid?(context=nil)
      #   if errors.any?
      #     false
      #   else
      #     super
      #   end
      # end

      def can_transition?(event_id)
        return false unless current_state.events[event_id]

        event = current_state.events[event_id].first
        transitions_to = event.transitions_to
        state_name = current_state.name

        within_transition(state_name, transitions_to, event_id) do
          valid?
        end
      end

      ###
      #
      # Executes the given block within a context that is able to give
      # correct answers to the questions, `:transitioning_from_<old_state>?`.
      # `:transitioning_to_<new_state>`, `:transitioning_via_event_<event_name>?`
      #
      # For use with validators, e.g. `validates :foobar, presence: true, if: :transitioning_to_some_state?`
      #
      # = Example:
      #
      #    before_transition do |from, to, name, *args|
      #      @halted = !within_transition from, to, name do
      #        valid?
      #      end
      #    end
      #
      def within_transition(from, to, event, &block)
        begin
          @transition_context = TransitionContext.new \
            from: from,
            to: to,
            event: event,
            event_args: []

          return block.call()
        ensure
          @transition_context = nil
        end
      end

      module ClassMethods
        def halt_transition_unless_valid!
          before_transition unless: :valid? do |model|
            throw :abort
          end
        end

        def wrap_transition_in_transaction!
          around_transition do |model, transition|
            model.with_lock do
              transition.call
            end
          end
        end
      end

      private

      def transitioning?(direction:, state:)
        state = state.to_sym
        return false unless transition_context
        case direction
        when 'from' then transition_context.from == state
        when 'to' then transition_context.to == state
        else transition_context.event == state
        end
      end
    end
  end
end
