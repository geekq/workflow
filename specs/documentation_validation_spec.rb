describe 'what is in the README' do
  
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
        # event(:delete)  { |msg| halt  msg }
        # event(:delete!) { |msg| halt! msg }
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
  
  it 'should halt' do
    @workflow = Workflow.reconstitute(:accepted, 'Article Workflow')
    @workflow.delete('coz i said so').should == false
    @workflow.halted?.should == true
    @workflow.state.should == :accepted
    @workflow.halted_because.should == 'coz i said so'
  end
  
  it 'should halt!' do
    raise
  end
  
  it 'halts with messages' do
    raise
  end
  
  it 'halts! with messages' do
    raise
  end
  
  it 'reflects states'
  it 'reflects events of a state'
  it 'reflects transitions_to of a state'
  
  it 'has meta relfection on states'
  it 'has meta relfection on events'
  
  it 'can iterate over state meta'
  it 'can iterate over event meta'
  
  it 'orders firing like action -> on_transition -> on_exit -> TRANSITION -> on_entry'

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
  
  it 'provides helpful extra info in NoMethodError'
  
end