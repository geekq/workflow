describe 'a simple machine' do
  
  setup do
    StateMachine.specify do
      state :new
      state :used
      state :broken
    end
    @machine = StateMachine.new
  end
  
  it 'should have 3 states, [:new, :used, :broken]' do
    @machine.states.should == [:new, :used, :broken]
  end
  
end