StateMachine.specify :item_lifecycle do

  initial_state :new

  state :new, :on_entry => :some_action, :on_exit => :some_other_action do
    event :upload, :triggers => :notify_editors_of_new_item,
          :transitions_to => :awaiting_approval
    event :delete, :transitions_to => :deleted_before_proofing
  end

  state :deleted_before_approved do
    event :reinstate, :triggers => :notify_editors_of_new_item,
          :transitions_to => :awaiting_approval
  end

  state :awaiting_approval do
    event :approve, :triggers => :notify_author_of_acceptance
          :transitions_to => :for_sale
    event :reject_tentatively, :triggers => :notify_author_tentative_rejection
          :transitions_to => :requires_work_before_approval
  end

  state :requires_work_before_approval do
    event :update, :triggers => :notify_editors_of_new_item,
          :transitions_to => :awaiting_approval
    event :delete, :transitions_to => :deleted_before_proofing
  end

  state :for_sale do
    event :disable, :triggers => :notify_author_that_item_was_disabled
          :transitions_to => :disabled
    event :delete, :transitions_to => :deleted
  end
  
  state :disabled do
    event :enable, :triggers => :notify_author_that_item_was_enabled,
          :transitions_to => :for_sale
  end
  
  state :deleted do
    event :undelete, :transitions_to => :for_sale
  end
  
  action :notify_editors_of_new_item do
    # ...
  end

  action :notify_author_of_tentative_rejection do
    # ..
  end
  
  # ... the remainder of the actions
  
  on_transition do |from, to, triggering_event| 
    # hook into transitions, perhaps to record them?
  end
  
end

item_lifecycle_machine = StateMachine.new(:item_lifecycle)
# :some_action is called cuz :on_entry to :new
item_lifecycle_machine.current_state # => :new
item_lifecycle_machine.states # => [:new, :deleted_before_approved]