#
#
# THIS API MAY BE GROSSLY OUT OF DATE
# 
#

class Item < ActiveRecord::Base
  
  # include StateMachine::ClassIntegration
  include StateMachine::ActiveRecordIntegration # deals w/ serialization
  
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
      on_entry do |prior_state, triggering_event, *event_args|
        SomeCachingSingleton.add(self)
      end
      on_exit do |new_state, triggering_event, *event_args|
        SomeCachingSingleton.remove(self)
      end
      event :delete,  :transition_to => :deleted
      event :disable, :transition_to => :disabled
    end
    
    state :disabled do
      event :enable, :transition_to => :for_sale
    end
    
    state :deleted do
      event :undelete, :transition_to => :for_sale
    end
    
    on_transition |prior_state, new_state, triggering_event, *event_args| do
      # e.g. in the case of 'has_many :histories'
      self.histories.create!(:meta => {})
    end
    
  end
  
end