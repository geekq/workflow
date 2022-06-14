require File.join(File.dirname(__FILE__), 'test_helper')

$VERBOSE = false
require 'workflow'
require 'mocha/minitest'
require 'stringio'
#require 'ruby-debug'

class Order # here: activerecord independent. TODO: rename and review all test cases in main
  include Workflow
  workflow do
    state :submitted do
      event :accept, :transitions_to => :accepted, :meta => {:weight => 8} do |reviewer, args|
      end
    end
    state :accepted do
      event :ship, :transitions_to => :shipped
    end
    state :shipped
  end
end

class MainTest < Minitest::Test

  test 'on_entry and on_exit invoked' do
    c = Class.new
    callbacks = mock()
    callbacks.expects(:my_on_exit_new).once
    callbacks.expects(:my_on_entry_old).once
    c.class_eval do
      include Workflow
      workflow do
        state :new do
          event :age, :transitions_to => :old
        end
        on_exit do
          callbacks.my_on_exit_new
        end
        state :old
        on_entry do
          callbacks.my_on_entry_old
        end
        on_exit do
          fail "wrong on_exit executed"
        end
      end
    end

    o = c.new
    assert_equal 'new', o.current_state.to_s
    o.age!
  end

  test 'on_transition invoked' do
    callbacks = mock()
    callbacks.expects(:on_tran).once # this is validated at the end
    c = Class.new
    c.class_eval do
      include Workflow
      workflow do
        state :one do
          event :increment, :transitions_to => :two
        end
        state :two
        on_transition do |from, to, triggering_event, *event_args|
          callbacks.on_tran
        end
      end
    end
    assert nil != c.workflow_spec.on_transition_proc
    c.new.increment!
  end

  test 'access event meta information' do
    c = Class.new
    c.class_eval do
      include Workflow
      workflow do
        state :main, :meta => {:importance => 8}
        state :supplemental, :meta => {:importance => 1}
      end
    end
    assert_equal 1, c.workflow_spec.states[:supplemental].meta[:importance]
  end

  test 'initial state' do
    c = Class.new
    c.class_eval do
      include Workflow
      workflow { state :one; state :two }
    end
    assert_equal 'one', c.new.current_state.to_s
  end

  test 'including a child workflow definition for composable workflows' do
    child = Proc.new do
      state :two
    end

    c = Class.new
    c.class_eval do
      include Workflow
      workflow do
        state :one
        include child
        state :three
      end
    end
    assert_equal [:one, :two, :three], c.workflow_spec.states.keys
  end

  # TODO Consider following test case:
  # test 'multiple events with the same name and different arguments lists from different states'

  test 'implicit transition callback' do
    args = mock()
    args.expects(:my_tran).once # this is validated at the end
    c = Class.new
    c.class_eval do
      include Workflow
      def my_transition(args)
        args.my_tran
      end
      workflow do
        state :one do
          event :my_transition, :transitions_to => :two
        end
        state :two
      end

      private
      def another_transition(args)
        args.another_tran
      end
    end
    a = c.new
    a.my_transition!(args)
  end

  test '#53 Support for non public transition callbacks' do
    args = mock()
    args.expects(:log).with('in private callback').once
    args.expects(:log).with('in protected callback in the base class').once
    args.expects(:log).with('in protected callback `on_assigned_entry`').once

    b = Class.new # the base class with a protected callback
    b.class_eval do
      protected
      def assign_old(args)
        args.log('in protected callback in the base class')
      end

    end

    c = Class.new(b) # inheriting class with an additional protected callback
    c.class_eval do
      include Workflow
      workflow do
        state :new do
          event :assign, :transitions_to => :assigned
          event :assign_old, :transitions_to => :assigned_old
        end
        state :assigned
        state :assigned_old
      end

      protected
      def on_assigned_entry(prev_state, event, args)
        args.log('in protected callback `on_assigned_entry`')
      end

      private
      def assign(args)
        args.log('in private callback')
      end
    end

    a = c.new
    a.assign!(args)

    a2 = c.new
    a2.assign_old!(args)
  end

  test '#58 Limited private transition callback lookup' do
    args = mock()
    c = Class.new
    c.class_eval do
      include Workflow
      workflow do
        state :new do
          event :fail, :transitions_to => :failed
        end
        state :failed
      end
    end
    a = c.new
    a.fail!(args)
  end

  test 'Better error message for missing target state' do
    class Problem
      include Workflow
      workflow do
        state :initial do
          event :solve, :transitions_to => :solved
        end
      end
    end
    assert_raises Workflow::WorkflowError do
      Problem.new.solve!
    end
  end

  # Intermixing of transition graph definition (states, transitions)
  # on the one side and implementation of the actions on the other side
  # for a bigger state machine can introduce clutter.
  #
  # To reduce this clutter it is now possible to use state entry- and
  # exit- hooks defined through a naming convention. For example, if there
  # is a state :pending, then you can hook in by defining method
  # `def on_pending_exit(new_state, event, *args)` instead of using a
  # block:
  #
  #     state :pending do
  #       on_entry do
  #         # your implementation here
  #       end
  #     end
  #
  # If both a function with a name according to naming convention and the
  # on_entry/on_exit block are given, then only on_entry/on_exit block is used.
  test 'on_entry and on_exit hooks in separate methods' do
    c = Class.new
    c.class_eval do
      include Workflow
      attr_reader :history
      def initialize
        @history = []
      end
      workflow do
        state :new do
          event :next, :transitions_to => :next_state
        end
        state :next_state
      end

      def on_next_state_entry(prior_state, event, *args)
        @history << "on_next_state_entry #{event} #{prior_state} ->"
      end

      def on_new_exit(new_state, event, *args)
        @history << "on_new_exit #{event} -> #{new_state}"
      end
    end

    o = c.new
    assert_equal 'new', o.current_state.to_s
    assert_equal [], o.history
    o.next!
    assert_equal ['on_new_exit next -> next_state', 'on_next_state_entry next new ->'], o.history

  end

  test 'diagram generation' do
    begin
      $stdout = StringIO.new('', 'w')
      require 'workflow/draw'
      Workflow::Draw::workflow_diagram(Order, :path => '/tmp')
      assert_match(/run the following/, $stdout.string,
        'PDF should be generate and a hint be given to the user.')
    ensure
      $stdout = STDOUT
    end
  end

  test 'halt stops the transition' do
    c = Class.new do
      include Workflow
      workflow do
        state :young do
          event :age, :transitions_to => :old
        end
        state :old
      end

      def age(by=1)
        halt 'too fast' if by > 100
      end
    end

    joe = c.new
    assert joe.young?
    joe.age! 120
    assert joe.young?, 'Transition should have been halted'
    assert_equal 'too fast', joe.halted_because
  end

  test 'halt! raises exception immediately' do
    article_class = Class.new do
      include Workflow
      attr_accessor :too_far
      workflow do
        state :new do
          event :reject, :transitions_to => :rejected
        end
        state :rejected
      end

      def reject(reason)
        halt! 'We do not reject articles unless the reason is important' \
          unless reason =~ /important/i
        self.too_far = "This line should not be executed"
      end
    end

    article = article_class.new
    assert article.new?
    assert_raises Workflow::TransitionHalted do
      article.reject! 'Too funny'
    end
    assert_nil article.too_far
    assert article.new?, 'Transition should have been halted'
    article.reject! 'Important: too short'
    assert article.rejected?, 'Transition should happen now'
  end

  test 'can fire event?' do
    c = Class.new do
      include Workflow
      workflow do
        state :newborn do
          event :go_to_school, :transitions_to => :schoolboy
        end
        state :schoolboy do
          event :go_to_college, :transitions_to => :student
        end
        state :student
        state :street
      end
    end

    human = c.new
    assert human.can_go_to_school?
    assert_equal false, human.can_go_to_college?
  end

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

  test 'workflow graph generation' do
    require 'workflow/draw'
    Dir.chdir('/tmp') do
      capture_streams do
        Workflow::Draw::workflow_diagram(Order, :path => '/tmp')
      end
    end
  end

  test 'workflow graph generation in a path with spaces' do
    require 'workflow/draw'
    `mkdir -p '/tmp/Workflow test'`
    capture_streams do
      Workflow::Draw::workflow_diagram(Order, :path => '/tmp/Workflow test')
    end
  end

  def capture_streams
    old_stdout, $stdout = $stdout, StringIO.new
    yield
    $stdout
  ensure
    $stdout = old_stdout
  end

end
