describe 'specifying and instanciating named state machines' do
  
  setup do
    StateMachine.specify :alphabet_machine do
      initial_state :a
      state :a
      state :b
      state :c
    end
    StateMachine.specify :number_machine do
      initial_state :one
      state :one
      state :two
      state :three
    end
    @alphabet_machine = StateMachine.new(:alphabet_machine)
    @number_machine = StateMachine.new(:number_machine)
  end
  
  it 'should have states :a, :b, :c for @alphabet_machine' do
    @alphabet_machine.states.should == [:a, :b, :c]
  end
  
  it 'should have states :one, :two, :three for @number_machine' do
    @number_machine.states.should == [:one, :two, :three]
  end
  
end