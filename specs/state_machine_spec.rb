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

# named machines
# reflection
# reconstitution, and should not run exit/entry
# hooking into all transitionis w/ on_transition 
# binding to other object, bound context
# class integration
# AR integration? 
