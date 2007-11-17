describe 'a simple machine' do
  
  setup do
    StateMachine.specify do
      state :new
      state :used
      state :broken
      
      initial_state :new
    end
    @machine = StateMachine.new
  end
  
  it 'should have 3 states, [:new, :used, :broken]' do
    @machine.states.should == [:new, :used, :broken]
  end
  
  it 'should have :new as the current_state' do
    @machine.current_state.should == :new
  end
  
end