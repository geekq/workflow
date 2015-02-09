require File.join(File.dirname(__FILE__), 'test_helper')
require 'workflow'

class OnUnavailableTransitionTest < Test::Unit::TestCase

  class NoUnavailableTransitionBlock
    attr_reader :unavailable_transitions

    def initialize
      @unavailable_transitions = {}
    end

    include Workflow
    workflow do
      state :first
      state :second do
        event :backward, :transitions_to => :first
      end
    end
  end

  class UnavailableTransitionBlock
    attr_reader :unavailable_transitions

    def initialize
      @unavailable_transitions = {}
    end

    include Workflow
    workflow do
      state :first
      state :second do
        event :backward, :transitions_to => :first
      end
      on_unavailable_transition do |from, to_name, *args|
        @unavailable_transitions.merge!({:from => from, :to_name => to_name, :args => args})
      end
    end
  end

  class UnavailableTransitionBlockThrowsException
    attr_reader :unavailable_transitions

    def initialize
      @unavailable_transitions = {}
    end

    include Workflow
    workflow do
      state :first
      state :second do
        event :backward, :transitions_to => :first
      end
      on_unavailable_transition do |from, to_name, *args|
        @unavailable_transitions.merge!({:from => from, :to_name => to_name, :args => args})
        false
      end
    end
  end

  test 'that NoUnavailableTransitionBlock is raised when no on_unavailable_transition block is defined' do
    flow = NoUnavailableTransitionBlock.new
    assert_raise( Workflow::NoTransitionAllowed ) { flow.backward! }
    assert_equal({}, flow.unavailable_transitions)
    # transition should not happen
    assert_equal(true, flow.first?)
  end

  test 'that on_unavailable_transition block is called when an undefined event is called' do
    flow = UnavailableTransitionBlock.new
    assert_nothing_raised { flow.backward! }
    assert_equal({:from => :first, :to_name => :backward, :args=>[]}, flow.unavailable_transitions)
    # transition should not happen
    assert_equal(true, flow.first?)
  end

  test 'that on_unavailable_transition block is called when an undefined event is called and throws NoUnavailableTransitionBlock as false is returned' do
    flow = UnavailableTransitionBlockThrowsException.new
    assert_raise( Workflow::NoTransitionAllowed ) { flow.backward! }
    assert_equal({:from => :first, :to_name => :backward, :args=>[]}, flow.unavailable_transitions)
    # transition should not happen
    assert_equal(true, flow.first?)
  end

end