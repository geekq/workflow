require File.join(File.dirname(__FILE__), 'test_helper')

$VERBOSE = false
require 'active_record'
require 'sqlite3'
require 'workflow'

ActiveRecord::Migration.verbose = false

class Task < ActiveRecord::Base
  include Workflow

  # Use this to turn on active record validations when persisting a state change
  # to the workflow column.
  workflow_validate

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

class OptimisticLockingBlockTest < ActiveRecordTestCase

  def setup
    super

    ActiveRecord::Schema.define do
      create_table :tasks do |t|
        t.integer :duration
        t.string :workflow_state
        t.integer :lock_version, :default => 0
      end
    end
  end

  test 'with a race condition' do
    task = Task.create

    task1 = Task.find(task.id)
    task2 = Task.find(task.id)

    task1.pause!
    assert task1.paused?

    assert_raise ActiveRecord::StaleObjectError do
      task2.complete!
    end

    task.reload

    assert task.paused?
  end

  test 'with a block that saves successfully' do
    task = Task.create

    assert_nil task.duration

    task.pause! do
      task.duration = 1
    end

    task.reload

    assert task.paused?
    assert_equal 1, task.duration
  end

  test 'with a block and an illegal transition' do
    task = Task.create

    assert_nil task.duration

    task.pause! do
      task.duration = 1
    end

    task.reload

    assert_raise Workflow::NoTransitionAllowed do
      task.complete! do
        task.duration = 2
      end
    end

    task.reload

    assert task.paused?
    assert_equal 1, task.duration
  end

  test 'with a block and a race condition' do
    task = Task.create

    task1 = Task.find(task.id)
    task2 = Task.find(task.id)

    assert_nil task.duration

    task1.pause! do
      task1.duration = 1
    end

    assert task1.paused?

    assert_raise ActiveRecord::StaleObjectError do
      task2.complete! do
        task2.duration = 2
      end
    end

    task.reload

    assert task.paused?
    assert_equal 1, task.duration
  end
end
