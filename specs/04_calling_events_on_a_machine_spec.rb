describe 'calling events on a @machine' do
  
  setup do
    StateMachine.specify do
      state :for_sale do
        event :sell, :transition_to => :sold
        event :break, :transition_to => :broken
      end
      state :sold do
        event :auction, :transition_to => :for_sale
        event :break, :transition_to => :broken
      end
      state :broken
      initial_state :for_sale
    end
    @machine = StateMachine.new
  end
  
  #
  # UNGENERALIZE THIS FUCKING SPEC
  #
  
  it 'should be able to call events of a particular state' do
    lambda { @machine.sell }.should_not raise_error
  end
  
  it 'should transition to appropriate state when event is called' do
    @machine.sell
    @machine.current_state.should == :sold
  end
  
  it 'should raise appropriate exception when invalid event is called' do
    lambda { @machine.auction }.should raise_error(StateMachine::Exceptions::InvalidEvent, ':auction is an invalid event for state :for_sale, did you mean one of [:sell, :break]?')
  end
  
end