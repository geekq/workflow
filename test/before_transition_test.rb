require File.join(File.dirname(__FILE__), 'test_helper')
require 'workflow'

class BeforeTransitionTest < Test::Unit::TestCase
  class MyFlow
    attr_reader :history
    def initialize
      @history = []
    end

    include Workflow
    workflow do
      state :first do
        event :forward, :transitions_to => :second do
          @history << 'forward'
        end
      end
      state :second do
        event :back, :transitions_to => :first do
          @history << 'back'
        end
      end

      before_transition { @history << 'before' }
      after_transition { @history << 'after' }
      on_transition { @history << 'on' }
    end
  end

  test 'that before_transition is run before the action' do
    flow = MyFlow.new
    flow.forward!
    flow.back!
    assert flow.history == ['before', 'forward', 'on', 'after', 'before', 'back', 'on', 'after']
  end
end
