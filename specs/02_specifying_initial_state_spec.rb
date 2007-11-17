describe 'specifying the initial state of a @machine' do

  setup do
    StateMachine.specify do
      state :new
      state :used
      state :broken
      initial_state :new
    end
    @machine = StateMachine.new
  end
  
  it 'should have the initial_state as the current_state' do
    @machine.current_state.should == :new
  end
  
end