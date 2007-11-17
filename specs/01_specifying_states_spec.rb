describe 'specifying states of a @machine' do
  
  setup do
    StateMachine.specify do
      state :new
      state :used
      state :broken
    end
    @machine = StateMachine.new
  end
  
  it 'should have the specified states' do
    @machine.states.should == [:new, :used, :broken]
  end
    
end