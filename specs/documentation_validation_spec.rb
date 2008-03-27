# %w(rubygems spec).each { |lib| require lib }
# require '../workflow'

describe 'what is in the README' do
  
  setup do
    Workflow.specify 'Article Workflow' do
      state :new do
        event :submit, :transitions_to => :awaiting_review
      end
      state :awaiting_review do
        event :review, :transitions_to => :being_reviewed
      end
      state :being_reviewed do
        event :accept, :transitions_to => :accepted
        event :reject, :transitions_to => :rejected
      end
      state :accepted
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
  
end