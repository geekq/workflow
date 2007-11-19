describe 'a very simple machine - two states, one event' do
  
  setup do
    StateMachine.specify do
      state :new do
        event :purchase, :transitions_to => :used
      end
      state :used
    end
    @machine = StateMachine.new
  end

  it 'should have two states' do
    @machine.states.length.should == 2
  end

  it 'should have the first state as the initial state' do
    @machine.current_state.should == @machine.find_state_by_name(:new)
  end
  
  it 'should transition to used when purchase even called' do
    @machine.purchase
    @machine.current_state.should == @machine.find_state_by_name(:used)
  end
    
end

describe 'a machine with event actions' do
  
  setup do
    StateMachine.specify do
      state :for_sale do
        event :sell, :transitions_to => :sold do
          record "#{self.class} was sold"
        end
        state :sold do
          event :auction, :transitions_to => :for_sale do |reserve|
            record "#{self.class} w/ reserve of #{reserve}"
          end
        end
      end
    end
    @machine = StateMachine.new
    @machine.extend(Recorder)
  end
  
  it 'should run event action in context of machine' do
    @machine.sell
    @machine.records.last == 'StateMachine::Machine was sold'
  end
  
  it 'should pass in paramaters in context of machine' do
    @machine.sell
    @machine.auction(10)
    @machine.records.last.should == 'StateMachine::Machine w/ reserve of 10'
  end
  
end

describe 'a machine with on exit and on entry actions' do
  
  setup do
    StateMachine.specify do
      state :looking_for_speeders do
        event :speeding_car_detected, :transitions_to => :taking_photo
      end
      state :taking_photo do
        on_entry do |prior_state, triggering_event, *event_args|
          record [prior_state, triggering_event]+event_args
        end
        event :photo_taken, :transitions_to => :looking_for_speeders do |photo|
          # ... we just care about testing for the photo arg in on_exit
        end
        on_exit do |new_state, triggering_event, *event_args|
          record [new_state, triggering_event]+event_args
        end
      end
    end
    @machine = StateMachine.new
    @machine.extend(Recorder)
  end
  
  it 'should trigger on_entry for taking_photo' do
    @machine.speeding_car_detected
    @machine.records.last.should == [@machine.find_state_by_name(:looking_for_speeders), :speeding_car_detected]
  end
  
  it 'should trigger on_exit for taking_photo' do
    @machine.speeding_car_detected
    @machine.photo_taken(:a_photo)
    @machine.records.last.should == [@machine.find_state_by_name(:looking_for_speeders), :photo_taken, :a_photo]
  end
  
end

describe 'specifying and instanciating named state machines' do
  
  setup do
    StateMachine.specify :alphabet_machine do
      state :a
      state :b
      state :c
    end
    StateMachine.specify :number_machine do
      state :one
      state :two
      state :three
    end
    @alphabet_machine = StateMachine.new(:alphabet_machine)
    @number_machine = StateMachine.new(:number_machine)
  end
    
  it 'should have states :a, :b, :c for @alphabet_machine' do
    a = @alphabet_machine.find_state_by_name(:a)
    b = @alphabet_machine.find_state_by_name(:b)
    c = @alphabet_machine.find_state_by_name(:c)
    @alphabet_machine.states.should == [a, b, c]
  end
  
  it 'should have states :one, :two, :three for @number_machine' do
    one = @number_machine.find_state_by_name(:one)
    two = @number_machine.find_state_by_name(:two)
    three = @number_machine.find_state_by_name(:three)
    @number_machine.states.should == [one, two, three]
  end
  
end

describe 'reconstitution of a machine (say, from a serialised object)' do
  
  setup do
    StateMachine.specify do
      state :first
      state :second
      state :third
    end
    @machine = StateMachine.reconstitute(:second)
  end
  
  it 'should reconstitute at second' do
    @machine.current_state.should == @machine.find_state_by_name(:second)
  end
  
  it 'should not execute on_entry when reconsituting a machine'
  it 'should be possible to specify a named machine to reconsitute'
  
end

describe 'a machine with an on transition hook' do  
  
  setup do
    StateMachine.specify do
      state(:first)  { event(:next, :transitions_to => :second) { |i| nil } }
      state(:second) { event(:next, :transitions_to => :third)  { |i| nil } }
      state(:third)  { event(:back, :transitions_to => :second) { |i| nil } }
      on_transition do |from, to, triggering_event, *event_args|
        record [from, to, triggering_event]+event_args
      end
    end
    @machine = StateMachine.new
    @machine.extend(Recorder)
  end
  
  it 'should execute the hook on any transition of state, passing args' do
    @machine.next(1) # => to :second
    @machine.next(2) # => to :third
    @machine.back(3) # => back to :second
    first = @machine.find_state_by_name(:first)
    second = @machine.find_state_by_name(:second)
    third = @machine.find_state_by_name(:third)
    @machine.records[0].should == [first, second, :next, 1]
    @machine.records[1].should == [second, third, :next, 2]
    @machine.records[2].should == [third, second, :back, 3]
  end
  
end

describe 'binding machines to another context' do
  
  setup do
    StateMachine.specify do
      state(:first)  { event(:next, :transitions_to => :second) {|i| record i }}
      state(:second) { event(:next, :transitions_to => :third)  {|i| record i }}
      state :third do 
        event(:next, :transitions_to => :fourth)
        event(:back, :transitions_to => :second) {|i| record i }
        on_entry do |prior_state, triggering_event, *event_args|
          record 'entered :third'
        end
        on_exit do |new_state, triggering_event, *event_args|
          record 'exited :third'
        end
      end
      state :fourth
      on_transition do |from, to, triggering_event, *args|
        record "transitioned from #{from.name} to #{to.name}"
      end
    end
    @context = Object.new
    @context.extend(Recorder)
    @context.instance_eval do
      def method_missing(method, *args)
        "you hit #{method.inspect}"
      end
    end
    @machine = StateMachine.new
    @machine.bind_to(@context)
  end
  
  it 'should execute event actions in context' do
    @machine.next(:a)
    @context.records.should include(:a)
  end
  
  it 'should execute on_entry in context' do
    @machine.next(:a)
    @machine.next(:b)
    @context.records.should include('entered :third')
  end
  
  it 'should execute on_exit in context' do
    @machine.next(:a)
    @machine.next(:b)
    @machine.next(:c)
    @context.records.should include('exited :third')
  end
  
  it 'should execute on_transition in context' do
    @machine.next(:a)
    @context.records.should include('transitioned from first to second')
  end
  
  it 'should have a current_state accessor' do
    @context.current_state.should == @machine.find_state_by_name(:first)
  end
  
  it 'should chain-patch method_missing to respond to events' do
    @context.next(:a)
    @context.x.should == 'you hit :x'
    @context.current_state.should == @machine.find_state_by_name(:second)
  end
  
  it 'should have access to relfection, when we implement it'
  
end

#
# STOP HERE AND GO TO SLEEP DAMNIT!
#

describe 'the class integration mixin' do
  it 'should set up a state_machine class method for describing the machine'
  it 'should instanciate a machine on initialize'
  it 'should behave like a typical binding'
  it 'should work with inhertiance'
end

describe 'active record integration mixin' do
  it 'should do what the class integration mixin does'
  it 'should handle serializing '
end

describe 'reflecting machines' do
  it 'should allow you to intuitively reflect states'
  it 'should allow you to intuitively reflect allowable events in states'
end

describe 'plain old quality' do
  it 'should not use active support\'s instance_eval'
  it 'should have more DRY method args, y\'know?'
end

describe 'more sophisticated error handling' do
  it 'should compare arity of procs when passing args to events'
  it 'should carry on if you say transitions_to a non-existant state'
  it 'should be a bit more informative on method_missing, tell of events?'
  it 'should provide helpful information if you fuck up the DSL'
  it 'should specifically raise errors when you forget :transitions_to'
end