require "#{File.dirname(__FILE__)}/bootstrap"

describe 'As described in README,' do
  
  setup do
    Workflow.specify 'Article Workflow', :meta => {:is_for => :articles_duh} do
      state :new do
        event :submit, :transitions_to => :awaiting_review
      end
      state :awaiting_review, :meta => {:one => 1} do
        event :review, :transitions_to => :being_reviewed do |reviewer|
          reviewer << 'oi!'
        end 
      end
      state :being_reviewed do
        event :accept, :transitions_to => :accepted, :meta => {:two, 2}
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
      state :rejected do
        on_entry do |old_state, event_fired, *event_args|
          $on_entry_old_state = old_state
          $on_entry_event_fired = event_fired 
          $on_entry_event_args = event_args
        end
      end
      on_transition do |old_state, new_state, triggering_event, *event_args|
        $on_transition_old_state = old_state
        $on_transition_new_state = new_state
        $on_transition_triggering_event = triggering_event
        $on_transition_event_args = event_args
      end
    end
    @workflow = Workflow.new('Article Workflow')
    # @object = Object.new; @workflow.bind_to(@object); @workflow = @object
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

  it 'should be like, cool with on_entry' do
    @workflow.submit
    @workflow.review('')
    @workflow.reject('coz i said so')
    $on_entry_old_state.should == :being_reviewed
    $on_entry_event_fired.should == :reject
    $on_entry_event_args.should == ['coz i said so']
  end

  it 'should be like, cool with on_exit' do
    @workflow.submit
    @workflow.review('')
    @workflow.reject('coz i said so')
    $on_exit_new_state.should == :rejected
    $on_exit_event_fired.should == :reject
    $on_exit_event_args.should == ['coz i said so']
  end
  
  it 'should be like, cool with on_transition' do
    @workflow.submit(1,2,3)
    $on_transition_old_state.should == :new
    $on_transition_new_state.should == :awaiting_review
    $on_transition_triggering_event.should == :submit
    $on_transition_event_args.should == [1,2,3]
  end
  
  describe 'halting' do
    
    before do
      @workflow = Workflow.reconstitute(:accepted, 'Article Workflow')
      @reason = 'i said so'      
    end
    
    describe 'with #halt' do
      
      before do
        @return_value = @workflow.delete(@reason)
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
        @workflow.halted_because.should == @reason
      end
      
    end
    
    describe 'with #halt!' do
      
      before do
        begin
          @exception_raised = nil
          @return_value = @workflow.delete!(@reason)
        rescue Workflow::Instance::TransitionHalted => e
          @exception_raised = e
        end
      end
      
      it 'raises a Workflow::Halted exception' do
        @exception_raised.should be_kind_of(Workflow::Instance::TransitionHalted)
      end
      
      it 'has halted?' do
        @workflow.halted?.should == true
      end
      
      it 'should not transition' do
        @workflow.state.should == :accepted
      end
      
      it 'has a message on Workflow#halted_because' do
        @workflow.halted_because.should == @reason
      end
      
      it 'has a message on Workflow::Halted#halted_because' do
        @exception_raised.halted_because.should == @reason
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
    
    describe 'metadata' do
      
      describe 'of an instance' do
        
        it 'works like a hash' do
          @workflow.meta.should == {:is_for => :articles_duh}
        end
        
        it 'initializes as an empty hash if not specified' do
          Workflow.specify('Empty!') { state :just_this_one }
          Workflow.new('Empty!').meta.should == {}
        end
        
        it 'behaves like an object'
        
      end

      describe 'of a state' do

        it 'works like a hash' do
          @workflow.states(:awaiting_review).meta.should == {:one => 1}
        end

        it 'initializes as an empty hash if not specified' do
          @workflow.states(:new).meta.should == {}
        end

        it 'behaves like an object'

      end

      describe 'of an event' do

        it 'works like a hash' do
          @workflow.states(:being_reviewed).events(:accept).meta.should == {:two => 2}
        end

        it 'initializes as an empty hash if not specified' do
          @workflow.states(:new).events(:submit).meta.should == {}
        end

        it 'behaves like an object'

      end

    end
    
  end
    
  it 'fires action -> on_transition -> on_exit -> TRANSITION -> on_entry' do
    Workflow.specify 'Strictly Ordering' do
      state :start do
        event(:go!, :transitions_to => :finish) { $order << :action }
        on_exit { $order << :on_exit }
      end
      state :finish do
        on_entry { $order << :on_entry }
      end
      on_transition { $order << :on_transition }
    end
    $order = []
    @workflow = Workflow.new('Strictly Ordering')
    @workflow.go!
    $order.should == [:action, :on_transition, :on_exit, :on_entry]
  end
  
  it 'provides helpful extra info in NoMethodError'
  it 'tests NoMethodError extensively, with like, stuff and contexts OKOK?!!1'

  # :)

  describe 'class integration' do
    
    before do
      GotWorkflow = Class.new; GotWorkflow.class_eval do
        include Workflow
        workflow do
          state :first do
            event :forward, :transitions_to => :second
          end
          state :second do
            event :forward, :transitions_to => :third
            event :backward, :transitions_to => :first
          end
          state :third do
            event :backward, :transitions_to => :second
          end
        end
      end
      @got_workflow = GotWorkflow.new
    end

    it 'has a workflow' do
      @got_workflow.workflow.should be_kind_of(Workflow::Instance)
    end
    
    it 'is bound to the workflow context, which implies scope and etc...' do
      @got_workflow.workflow.context.should == @got_workflow
    end
    
    it 'has a method missing proxy, and proxies' do
      @got_workflow.workflow.should_receive(:state)
      @got_workflow.state
    end
    
    it 'test it kinda like integration style, lols' do
      @got_workflow.states.should == [:first, :second, :third]
      @got_workflow.states(:second).events.should == [:forward, :backward]
      @got_workflow.state.should == :first
      @got_workflow.forward
      @got_workflow.state.should == :second
      @got_workflow.forward
      @got_workflow.state.should == :third
      @got_workflow.backward
      @got_workflow.state.should == :second
      @got_workflow.backward
      @got_workflow.state.should == :first
    end
    
  end
  
  describe 'AR integration' do
    before do
      # setup junk for our @ar mock
    end
    it 'should save to a field called state by default'
    [:state, :workflow_state, :something_random].each do |field|
      it "should initialize in default state if #{field} is null"
      it "should reconstitute in state if #{field} is not null"
      it "should raise exception if value in #{field} is not a valid state"
      it "should serialize out to #{field} before save"
    end
  end
  
  describe 'blatting' do
    it 'can introduce new states'
    it 'can introduce new events in states'
    it 'can overwrite transitions_to in existing events'
  end
  
end