describe 'The README API:' do
  
  setup do
    Workflow.specify 'Article Workflow' do
      state :new do
        event :submit, :transitions_to => :awaiting_review
      end
      state :awaiting_review do
        event :review, :transitions_to => :being_reviewed do |reviewer|
          reviewer << 'oi!'
        end 
      end
      state :being_reviewed do
        event :accept, :transitions_to => :accepted
        event :reject, :transitions_to => :rejected
        on_exit do |new_state, event_fired, *event_args|
          $on_exit_new_state = new_state
          $on_exit_event_fired = event_fired 
          $on_exit_event_args = event_args
        end
      end
      state :accepted do
        event(:delete)  { |msg| halt  msg }
        event(:delete!) { |msg| halt! msg }
      end
      state :rejected
    end
    @workflow = Workflow.new('Article Workflow')
  end
  
  it 'has a default state of :new' do
    @workflow.state.should == :new
  end
  
  it 'transitions to :awaiting_review on :submit' do
    @workflow.submit
    @workflow.state.should == :awaiting_review
  end
  
  it 'likes predicates for quering of current state' do
    @workflow.new?.should == true
    @workflow.awaiting_review?.should == false
    @workflow.submit
    @workflow.new?.should == false
    @workflow.awaiting_review?.should == true
  end
  
  it 'should do stuff with args to events' do
    @workflow.submit
    @reviewer = ''
    @workflow.review(@reviewer)
    @reviewer.should == 'oi!'
  end
  
  it 'should be like, cool with on_entry' # do
    # @workflow.submit
    # @workflow.review('')
    # @workflow.reject('coz i said so')
    # $on_exit_new_state.should == :rejected
    # $on_exit_event_fired.should == :reject
    # $on_exit_event_args.should == ['coz i said so']
  # end
  
  it 'should be like, cool with on_exit'
  it 'should be like, cool with on_transition'
  
  describe 'halting' do
    
    before do
      @workflow = Workflow.reconstitute(:accepted, 'Article Workflow')
      @halted_because = 'i said so'      
    end
    
    describe 'with #halt' do
      
      before do
        @return_value = @workflow.delete(@halted_because)
      end
      
      it 'returns false from the event' do
        @return_value.should == false
      end
      
      it 'has halted?' do
        @workflow.halted?.should == true
      end
      
      it 'should not transition' do
        @workflow.state.should == :accepted
      end
      
      it 'has a message on Workflow#halted_because' do
        @workflow.halted_because.should == @halted_because
      end
      
    end
    
    describe 'with #halt!' do
      
      before do
        begin
          @exception_raised = nil
          @return_value = @workflow.delete!(@halted_because)
        rescue Workflow::Halted => e
          @exception_raised = e
        end
      end
      
      it 'raises a Workflow::Halted exception' do
        @exception_raised.should be_kind_of(Workflow::Halted)
      end
      
      it 'has halted?' do
        @workflow.halted?.should == true
      end
      
      it 'should not transition' do
        @workflow.state.should == :accepted
      end
      
      it 'has a message on Workflow#halted_because' do
        @workflow.halted_because.should == @halted_because
      end
      
      it 'has a message on Workflow::Halted#halted_because' do
        @exception_raised.halted_because.should == @halted_because
      end
      
    end
    
  end
  
  describe 'reflection' do
  
    it 'reflects states' do
      @workflow.states.should == [:new, :awaiting_review, :being_reviewed, :accepted, :rejected]
    end
    
    it 'reflects events of a state' do
      @workflow.states(:being_reviewed).events.should == [:accept, :reject]
    end
    
    it 'reflects transitions_to of an event' do
      @workflow.states(:new).events(:submit).transitions_to.should == :awaiting_review
    end
    
    it 'meta-reflects on a state'
    it 'meta-reflects on an event'
    it 'iterates over state meta'
    it 'iterates over event meta'
    
  end
    
  it 'fires action -> on_transition -> on_exit -> TRANSITION -> on_entry'
  it 'provides helpful extra info in NoMethodError'

  # :)

  describe 'class integration' do
    it 'has a meta method called workflow'
    it 'has a workflow method on the instances'
    it 'proxies states to the workflow'
    it 'proxies events to the workflow'
    it 'has the instance as the action scope'
  end
  
  describe 'AR integration' do
    it 'serializes state on_transition ?'
    it 'reconsitutes from state on find ?'
  end
  
end