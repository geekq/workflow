require File.join(File.dirname(__FILE__), 'test_helper')

$VERBOSE = false
require 'workflow'

class BlockWithoutActiveRecord < Test::Unit::TestCase
  class Task
    attr_accessor :duration

    include Workflow

    workflow do
      state :active do
        event :pause, :transitions_to => :paused
        event :complete, :transitions_to => :completed
      end
      state :paused do
        event :resume, :transitions_to => :active
      end
      state :completed
    end
  end

  test 'with a block that transitions successfully' do
    task = Task.new

    assert_nil task.duration

    task.pause! do
      task.duration = 1
    end

    assert task.paused?
    assert_equal 1, task.duration
  end

  test 'with a block and an illegal transition' do
    task = Task.new

    assert_nil task.duration

    task.pause! do
      task.duration = 1
    end

    assert_raise Workflow::NoTransitionAllowed do
      task.complete! do
        task.duration = 2
      end
    end

    assert task.paused?
    assert_equal 1, task.duration
  end
end
