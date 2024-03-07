require File.join(File.dirname(__FILE__), 'test_helper')
require 'workflow'

class SymbolCallbacksTest < Minitest::Test

  test "symbol callbacks" do

    c = Class.new
    c.class_eval do
      include Workflow

      attr_reader :events

      def record(event)
        @events ||= []
        @events << event
      end

      def ran?(event)
        @events.include? event
      end

      def clear_events
        @events = []
      end

      def event_1(test)
        # puts "running event_1 with arg '#{test}'"
        record __method__
      end

      def before_transition(from, to, triggering_event, *args, **kwargs)
        # puts "before_transition #{from} -> #{to}, #{triggering_event}, #{args}, #{kwargs}"
        record __method__
      end

      def on_transition(from, to, triggering_event, *args, **kwargs)
        # puts "on_transition #{from} -> #{to}, #{triggering_event}, #{args}, #{kwargs}"
        record __method__
      end

      def after_transition(from, to, triggering_event, *args, **kwargs)
        # puts "after_transition #{from} -> #{to}, #{triggering_event}, #{args}, #{kwargs}"
        record __method__
      end

      def event_1_condition?
        # puts "event_1_condition? -> true"
        record __method__
        true
      end

      def on_state_1_exit(new_state, event, *args)
        # puts "on_state_1_exit(#{new_state}, #{event}, #{args})"
        record __method__
      end

      def entering_state_2(prior_state, triggering_event, *args, **kwargs)
        # puts "entering_state_2 #{prior_state}, #{triggering_event}, #{args}, #{kwargs}"
        record __method__
      end

      def entering_state_3(prior_state, triggering_event, *args, **kwargs)
        # puts "entering_state_3 #{prior_state}, #{triggering_event}, #{args}, #{kwargs}"
        record __method__
      end

      def on_state_2_entry(new_state, event, *args)
        # puts "on_state_2_entry(#{new_state}, #{event}, #{args})"
        record __method__
      end

    end

    ran_normal = []
    hash = {
      state_1: {
        events: {
          event_1: {
            transition_to: :state_2,
            if: :event_1_condition?,
            meta: { e1: 1 }
          },
        },
        meta: { a: 1 }
      },
      state_2: {
        events: {
          event_2: {
            transition_to: :state_3,
          }
        },
        on_entry: :entering_state_2,
        meta: { a: 2 }
      },
      state_3: { 
        on_entry: "entering_state_3",
      }
    }

    spec = Workflow::Specification.new do
      
      hash.each_pair do |state_name, state_def|
        
        state state_name, state_def

        on_entry state_def[:on_entry] if state_def[:on_entry].present?
        on_exit { ran_normal << :on_exit }

        state_def[:events]&.each_pair do |event_name, event_def|
          event event_name, event_def
        end

      end

      before_transition do |from, to, triggering_event, *args, **kwargs|
        ran_normal << :before_transition
      end

      on_transition do |from, to, triggering_event, *args, **kwargs|
        ran_normal << :on_transition
      end

      after_transition do |from, to, triggering_event, *args, **kwargs|
        ran_normal << :after_transition
      end

    end

    c.send :assign_workflow, spec

    o = c.new

    assert o.state_1?, "Should be state_1"
    refute o.state_2?, "Should not be state_2"

    o.event_1! "hello"
    [:event_1_condition?, :event_1, :entering_state_2, :before_transition, :on_transition, :after_transition].each do |event|
      assert o.ran?(event), "Should have run event #{event}"
    end

    refute o.state_1?, "Should not be state_1"
    assert o.state_2?, "Should be state_2"

    o.clear_events
    o.event_2!
    refute o.ran?(:event_1), "Should not have run event_1"
    [:entering_state_3, :before_transition, :on_transition, :after_transition].each do |event|
      assert o.ran?(event), "Should have run event #{event}"
    end

    assert ran_normal.include?(:before_transition), "Should have run before_transition proc"
    assert ran_normal.include?(:on_transition), "Should have run on_transition proc"
    assert ran_normal.include?(:after_transition), "Should have run after_transition proc"
    assert ran_normal.include?(:on_exit), "Should have run on_exit proc"

  end
end
