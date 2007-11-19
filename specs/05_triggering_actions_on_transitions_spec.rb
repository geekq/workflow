describe 'triggering actions when calling events on a @machine' do
  
  setup do
    StateMachine.specify do
      initial_state :for_sale
      state :for_sale do
        event :sell, :transition_to => :sold, :trigger => :notify_of_sale
        event :break, :transition_to => :broken, 
              :trigger => [:tell_manager_of_screw_up, :throw_item_in_the_trash]
      end
      state :sold do
        event :auction, :transition_to => :for_sale, 
              :trigger => :place_in_aution_house
        event :break, :transition_to => :broken, 
              :trigger => :throw_item_in_the_trash
      end
      state :broken
      action(:notify_of_sale)           { record :notify_of_sale }
      action(:tell_manager_of_screw_up) { record :tell_manager_of_screw_up }
      action(:throw_item_in_the_trash)  { record :throw_item_in_the_trash }
      action(:place_in_aution_house)    { record :place_in_aution_house }
    end
    @machine = StateMachine.new
    @machine.extend(Recorder)
  end
  
  it 'should run notify_of_sale on sell event when for_sale' do
    @machine.sell
    @machine.records.should == [:notify_of_sale]
  end
  
  it 'should run tell_manager_of_screw_up and throw_item_in_the_trash on break event when for_sale' do
    @machine.break
    @machine.records.should == [:tell_manager_of_screw_up,
                                :throw_item_in_the_trash]
  end
  
  it 'should run place_in_aution_house on auction when sold' do
    @machine.sell # transition to :sold
    @machine.auction
    @machine.records.should == [:notify_of_sale, :place_in_aution_house]
  end
  
  it 'should run throw_item_in_the_trash on break when sold' do
    @machine.sell # transition to :sold
    @machine.break
    @machine.records.should == [:notify_of_sale, :throw_item_in_the_trash]
  end
  
end