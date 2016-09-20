require 'workflow/state'
require 'workflow/event'
require 'workflow/event_collection'
require 'workflow/errors'
require 'active_support/callbacks'

module Workflow
  class Specification
    include ActiveSupport::Callbacks

    attr_accessor :states, :initial_state, :meta, :around_transition_proc,
      :on_transition_proc, :before_transition_proc, :after_transition_proc, :on_error_proc

    define_callbacks :spec_definition

    set_callback(:spec_definition, :after, if: :define_revert_events?) do |spec|
      spec.state_names.each do |state_name|
        state = spec.states[state_name]

        state.events.flat.reject{|e| e.name.to_s =~ /^revert_/ }.each do |event|
          revert_event_name = "revert_#{event.name}"
          revert_event = Workflow::Event.new(revert_event_name, state)
          from_state_for_revert = spec.states[event.transitions_to.to_sym]
          from_state_for_revert.events.push revert_event_name, revert_event
        end
      end
    end

    def initialize(meta = {}, &specification)
      @states = Hash.new
      @meta = meta
      run_callbacks :spec_definition do
        instance_eval(&specification)
      end
    end

    def state_names
      states.keys
    end

    private

    def define_revert_events!
      @define_revert_events = true
    end

    def define_revert_events?
      !!@define_revert_events
    end

    def state(name, meta = {:meta => {}}, &events_and_etc)
      # meta[:meta] to keep the API consistent..., gah
      new_state = Workflow::State.new(name, self, meta[:meta])
      @initial_state = new_state if @states.empty?
      @states[name.to_sym] = new_state
      @scoped_state = new_state
      instance_eval(&events_and_etc) if events_and_etc
    end

    def event(name, args = {}, &action)
      target = args[:transitions_to] || args[:transition_to]
      condition = args[:if]
      raise WorkflowDefinitionError.new(
        "missing ':transitions_to' in workflow event definition for '#{name}'") \
        if target.nil?
      @scoped_state.events.push(
        name, Workflow::Event.new(name, target, condition, (args[:meta] or {}), &action)
      )
    end

    def on_entry(&proc)
      @scoped_state.on_entry = proc
    end

    def on_exit(&proc)
      @scoped_state.on_exit = proc
    end

    def after_transition(&proc)
      @after_transition_proc = proc
    end

    def around_transition(&proc)
      @around_transition_proc = proc
    end

    def before_transition(&proc)
      @before_transition_proc = proc
    end

    def on_transition(&proc)
      @on_transition_proc = proc
    end

    def on_error(&proc)
      @on_error_proc = proc
    end
  end
end
