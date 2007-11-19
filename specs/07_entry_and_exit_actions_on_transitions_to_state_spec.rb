describe 'firing on_entry and on_exit actions for states when transitioned' do
  
  setup do
    StateMachine.specify do
      initial_state :first
      state :first do
        event :next, :transition_to => :second
      end
      state :second, :on_entry => :mention_entry_to_second,
                     :on_exit  => :mention_exit_of_second do
        event :next, :transition_to => :third
        event :back, :transition_to => :first
      end
      state :third do
        event :back, :transition_to => :second
      end
      action(:mention_entry_to_second) { record :entered_second }
      action(:mention_exit_of_second)  { record :exited_second }
    end
    @machine = StateMachine.new
    @machine.extend(Recorder)
  end
  
  it 'shoud fire :mention_entry_to_second on entry of :second' do
    @machine.next
    @machine.records.should == [:entered_second]
  end
  
  it 'shoud fire :mention_exit_of_second on exit of :second' do
    @machine.next
    @machine.next
    @machine.records.should == [:entered_second, :exited_second]
  end
  
end