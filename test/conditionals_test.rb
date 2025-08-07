require File.join(File.dirname(__FILE__), 'test_helper')

$VERBOSE = false
require 'workflow'
require 'mocha/minitest'

class ConditionalsTest < Minitest::Test

  test 'can_<fire_event>? with conditions' do
    c = Class.new do
      include Workflow
      workflow do
        state :off do
          event :turn_on, :transitions_to => :on, :if => :sufficient_battery_level?
          event :turn_on, :transitions_to => :low_battery, :if => proc { |obj| obj.battery > 0 }
        end
        state :on
        state :low_battery
      end
      attr_reader :battery
      def initialize(battery)
        @battery = battery
      end

      def sufficient_battery_level?
        @battery > 10
      end
    end

    device = c.new 0
    assert_equal false, device.can_turn_on?

    device = c.new 5
    assert device.can_turn_on?
    device.turn_on!
    assert device.low_battery?
    assert_equal false, device.on?

    device = c.new 50
    assert device.can_turn_on?
    device.turn_on!
    assert device.on?
  end

  test 'gh-227 allow event arguments in conditions - test with a method' do
    c = Class.new do
      include Workflow
      # define more advanced workflow, where event methods allow arguments
      workflow do
        state :off do
          # turn_on and transition filters accepts additional argument `power_adapter`
          event :turn_on, :transitions_to => :on, :if => :sufficient_battery_level?
          event :turn_on, :transitions_to => :low_battery # otherwise
        end
        state :on do
          event :check, :transitions_to => :low_battery, :if => :check_low_battery?
          event :check, :transitions_to => :on # stay in on state otherwise
        end
        state :low_battery
      end
      attr_reader :battery
      def initialize(battery)
        @battery = battery
      end

      def sufficient_battery_level?(power_adapter)
        power_adapter || @battery > 10
      end

      def check_low_battery?() # supports no arguments, lets test below, what happens if the action uses addtional args
        # 'in check_low_battery? method'
      end
    end

    # test for conditions in a proc
    device = c.new 5
    device.turn_on!(true) # case with event arguments to be taken into account
    assert device.on?
    device.check!('foo') # the conditional in the definition above does not support arguments, but make it work
    # by ignoring superfluous arguments for compatibility
    assert device.on?
  end

  test 'gh-227 allow event arguments in conditions - test with a proc' do
    c = Class.new do
      include Workflow
      # define more advanced workflow, where event methods allow arguments
      workflow do
        state :off do
          # turn_on and transition filters accepts additional argument `power_adapter`
          event :turn_on, :transitions_to => :on, :if => proc { |obj, power_adapter| power_adapter || obj.battery > 10 }
          event :turn_on, :transitions_to => :low_battery # otherwise
        end
        state :on do
          # Use a lambda proc, which enforces correct arity
          event :check, :transitions_to => :low_battery, :if => -> (obj) { return false }
          event :check, :transitions_to => :on # stay in on state otherwise
        end
        state :low_battery
      end
      attr_reader :battery
      def initialize(battery)
        @battery = battery
      end
    end

    device = c.new 5
    device.turn_on!(true) # case with event arguments to be taken into account
    assert device.on?
    device.check!('foo') # also ensure that if conditional in the definition above does not support arguments,
    # it still works and just ignores superfluous arguments
    assert device.on?
  end

  test 'conditionals can accept keyword arguments' do
    c = Class.new do
      include Workflow

      workflow do
        state :inside do
          # method with kwarg
          event :leave, :transitions_to => :outside, if: :warm_outside?
        end
        state :outside do
          # method with positional arg and kwarg
          event :go_inside, :transitions_to => :in_office, if: :work_to_be_done?
        end
        state :in_office do
          # Lambda with kwarg
          event :relax, :transitions_to => :on_couch, if: -> (obj, hour:) { hour > 18 }
        end
        state :on_couch do
          # Lambda with positional arg and kwarg
          event :sleep, :transitions_to => :in_bed, if: -> (obj, sleepiness, hour:) { sleepiness > 10 && hour > 20  }
        end
        state :in_bed do
          # Proc/block with no arg
          event :wake_up, transitions_to: :awake, if: proc { |obj| true }
        end
        state :awake do
          # Proc/block with kwarg
          event :make_coffee, transitions_to: :caffienated, if: proc { |obj, decaf:| decaf }
        end
        state :caffienated
      end

      def warm_outside?(outside_temperature:)
        outside_temperature > 20
      end

      def work_to_be_done?(tasks_completed, quota:)
        tasks_completed < quota
      end
    end

    obj = c.new

    obj.leave!(outside_temperature: 21)
    assert obj.outside?

    obj.go_inside!(5, quota: 10)
    assert obj.in_office?

    obj.relax!(hour: 19)
    assert obj.on_couch?

    obj.sleep!(11, hour: 21)
    assert obj.in_bed?

    obj.wake_up!(hour: 9)
    assert obj.awake?

    obj.make_coffee!(decaf: true)
    assert obj.caffienated?
  end

end

