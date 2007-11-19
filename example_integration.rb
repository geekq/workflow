class Item << ActiveRecord::Base
  
  include StateMachine::ClassIntegration
  
  state_machine do
    
    initial_state :new
    
    state :new do
      
      event :upload, :transition_to => :awaiting_approval do
        save!
        notify_editors_of_new_file(self)
      end
      
    end
    
    state :awaiting_approval do
      
      event :approve, :transition_to => :for_sale do |approving_editor|
        self.approved_at = Time.now
        self.approving_editor = approving_editor
        save!
        notify_author_of_acceptance(self)
      end
      
      event :reject, :transition_to => :rejected do |rejecting_editor|
        self.rejected_at = Time.now
        self.rejecting_editor
      end
      
    end
    
    state :rejected
    
    state :for_sale, do
      entry { SomeCachingSingleton.add(self) }
      exit  { SomeCachingSingleton.remove(self) }
      event :delete,  :transition_to => :deleted
      event :disable, :transition_to => :disabled
    end
    
    state :disabled do
      event :enable, :transition_to => :for_sale
    end
    
    state :deleted do
      event :undelete, :transition_to => :for_sale
    end
    
    on_transition |old_state, new_state, event, *event_args| do
      Log.record_transition(old_state, new_state, event, event_args)
    end
    
  end
  
end