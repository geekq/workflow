describe 'specifying events in states for a @machine' do
  
  setup do
    StateMachine.specify do
      state :new do
        event :sell
      end
      state :used do
        event :onsell
        event :break
      end
      initial_state :new
    end
    @machine = StateMachine.new
  end
  
  it 'should have a sell event in new' do
    @machine.events_for_state(:new).should == [:sell]
  end
  
  it 'should have a onsell and break in used' do
    @machine.events_for_state(:used).should == [:onsell, :break]
  end
  
end