require "#{File.dirname(__FILE__)}/bootstrap"

describe 'a very simple workflow - two states, one event' do
  
  setup do
    Workflow.specify do
      state :new do
        event :purchase, :transitions_to => :used
      end
      state :used
    end
    @workflow = Workflow.new
  end

  it 'should have two states' do
    @workflow.states.length.should == 2
  end

  it 'should have the first state as the initial state' do
    @workflow.state.should == :new
  end
  
  it 'should transition to used when purchase even called' do
    @workflow.purchase
    @workflow.state.should == :used
  end
    
end

describe 'a workflow with event actions' do
  
  setup do
    Workflow.specify do
      state :for_sale do
        event :sell, :transitions_to => :sold do
          record "#{self.class} was sold"
        end
        event :steal, :transitions_to => :sold do |theif|
          record "#{self.class} protecting against #{theif}, the theif!"
          halt
        end
      end
      state :sold do
        event :auction, :transitions_to => :for_sale do |reserve|
          record "#{self.class} w/ reserve of #{reserve}"
        end
      end
    end
    @workflow = Workflow.new
    @workflow.extend(Recorder)
  end
  
  it 'should run event action in context of workflow' do
    @workflow.sell
    @workflow.records.last.should == 'Workflow::Instance was sold'
  end
  
  it 'should pass in paramaters in context of workflow' do
    @workflow.sell
    @workflow.auction(10)
    @workflow.records.last.should == 'Workflow::Instance w/ reserve of 10'
  end
  
  it 'should not transition if action calls halt!' do
    @workflow.steal('nasty man')
    @workflow.records.last.should == "Workflow::Instance protecting against nasty man, the theif!"
    @workflow.state.should == :for_sale
  end
  
end

describe 'a workflow with on exit and on entry actions' do
  
  setup do
    Workflow.specify do
      state :looking_for_speeders do
        event :speeding_car_detected, :transitions_to => :taking_photo
      end
      state :taking_photo do
        on_entry do |prior_state, triggering_event, *event_args|
          record [prior_state, triggering_event]+event_args
        end
        event :photo_taken, :transitions_to => :looking_for_speeders do |photo|
          # ... we just care about testing for the photo arg in on_exit
        end
        on_exit do |new_state, triggering_event, *event_args|
          record [new_state, triggering_event]+event_args
        end
      end
    end
    @workflow = Workflow.new
    @workflow.extend(Recorder)
  end
  
  it 'should trigger on_entry for taking_photo' do
    @workflow.speeding_car_detected
    @workflow.records.last.should == [:looking_for_speeders, :speeding_car_detected]
  end
  
  it 'should trigger on_exit for taking_photo' do
    @workflow.speeding_car_detected
    @workflow.photo_taken(:a_photo)
    @workflow.records.last.should == [:looking_for_speeders, :photo_taken, :a_photo]
  end
  
  it 'should not execute on_entry or on_exit on halt'
end

describe 'specifying and instanciating named state workflows' do
  
  setup do
    Workflow.specify :alphabet_workflow do
      state :a
      state :b
      state :c
    end
    Workflow.specify :number_workflow do
      state :one
      state :two
      state :three
    end
    @alphabet_workflow = Workflow.new(:alphabet_workflow)
    @number_workflow = Workflow.new(:number_workflow)
  end
    
  it 'should have states :a, :b, :c for @alphabet_workflow' do
    @alphabet_workflow.states.should == [:a, :b, :c]
  end
  
  it 'should have states :one, :two, :three for @number_workflow' do
    @number_workflow.states.should == [:one, :two, :three]
  end
  
end

describe 'reconstitution of a workflow (say, from a serialised object)' do
  
  setup do
    Workflow.specify do
      state :first
      state :second
      state :third
    end
    @workflow = Workflow.reconstitute(:second)
  end
  
  it 'should reconstitute at second' do
    @workflow.state.should == :second
  end
  
  it 'should not execute on_entry when reconsituting a workflow'
  it 'should be possible to specify a named workflow to reconsitute'
  
end

describe 'a workflow with an on transition hook' do  
  
  setup do
    Workflow.specify do
      state(:first)  { event(:next, :transitions_to => :second) { |i| nil } }
      state(:second) { event(:next, :transitions_to => :third)  { |i| nil } }
      state(:third)  { event(:back, :transitions_to => :second) { |i| nil } }
      on_transition do |from, to, triggering_event, *event_args|
        record [from, to, triggering_event]+event_args
      end
    end
    @workflow = Workflow.new
    @workflow.extend(Recorder)
  end
  
  it 'should execute the hook on any transition of state, passing args' do
    @workflow.next(1) # => to :second
    @workflow.next(2) # => to :third
    @workflow.back(3) # => back to :second
    @workflow.records[0].should == [:first, :second, :next, 1]
    @workflow.records[1].should == [:second, :third, :next, 2]
    @workflow.records[2].should == [:third, :second, :back, 3]
  end
  
  it 'should not execute hook on halt'
  it 'should act like a chain so we can go on_transition on_transition...'
end

describe 'binding workflows to another context' do
  
  setup do
    Workflow.specify do
      state(:first)  { event(:next, :transitions_to => :second) {|i| record i }}
      state(:second) { event(:next, :transitions_to => :third)  {|i| record i }}
      state :third do 
        event(:next, :transitions_to => :fourth)
        event(:back, :transitions_to => :second) {|i| record i }
        on_entry do |prior_state, triggering_event, *event_args|
          record 'entered :third'
        end
        on_exit do |new_state, triggering_event, *event_args|
          record 'exited :third'
        end
      end
      state :fourth
      on_transition do |from, to, triggering_event, *args|
        begin
          record "transitioned from #{from} to #{to}"
        rescue
          # ok ok shit fuck cunt arse motherfucker, nomethoderror
          # reraising on our behalfs were casing this to bunk up
          # coz it said from.name, to.name, lame lame lame (pls fix me ok?)
          raise "#{$!.inspect}"
        end
      end
    end
    @context = Object.new
    @context.extend(Recorder)
    @context.instance_eval do
      def method_missing(method, *args)
        "you hit #{method.inspect}"
      end
    end
    @workflow = Workflow.new
    @workflow.bind_to(@context)
  end
  
  it 'should just damn go from state to state' do
    @context.state.should == :first
    @context.next(nil)
    @context.state.should == :second
    @context.next(nil)
    @context.state.should == :third
    @context.next(nil)
    @context.state.should == :fourth
  end
  
  it 'should execute event actions in context' do
    @context.next(:a)
    @context.records.should include(:a)
  end
  
  it 'should execute on_entry in context' do
    @context.next(:a)
    @context.next(:b)
    @context.records.should include('entered :third')
  end
  
  it 'should execute on_exit in context' do
    @context.next(:a)
    @context.next(:b)
    @context.next(:c)
    @context.records.should include('exited :third')
  end
  
  it 'should execute on_transition in context' do
    @context.next(:a)
    @context.records.should include('transitioned from first to second')
  end
  
  it 'should have a current_state accessor, that maps to a State object' do
    @context.current_state.should == @workflow.states(:first)
  end
  
  it 'should have a state accessor, that maps to an :symbol' do
    @context.state.should == :first
  end
  
  it 'should chain-patch method_missing to respond to events' do
    @context.next(:a)
    @context.x.should == 'you hit :x'
    @context.state.should == :second
  end
  
  it 'should support blocks with method missing too!'
  # it 'should have access to relfection, when we implement it'
  it 'should act like a chain, i.e. so we can go on_exit on_exit...'
  # it 'should be ok using halt!'
end

#
# STOP HERE AND GO TO SLEEP DAMNIT!
#

describe 'the class integration mixin' do
  it 'should set up a workflow class method for describing the workflow'
  it 'should instanciate a workflow on initialize'
  it 'should behave like a typical binding'
  it 'should work with inhertiance'
end

describe 'active record integration mixin' do
  it 'should do what the class integration mixin does'
  it 'should handle serializing '
end

# describe 'reflecting workflows' do
  # it 'should allow you to intuitively reflect states'
  # it 'should allow you to intuitively reflect allowable events in states'
  # it 'should allow attachment of meta data to states and state events'
# end

describe 'plain old quality' do
  it 'HANDLES NOMETHODERROR FOR ONLY THE PROXIED OBJECTS FFS!!! (see swearing above)'
  it 'should not use active support\'s instance_eval'
  it 'should have more DRY method args, y\'know? (wtf does this mean?)'
end

describe 'more sophisticated error handling' do
  it 'should compare arity of procs when passing args to events'
  it 'should carry on if you say transitions_to a non-existant state'
  it 'should be a bit more informative on method_missing, tell of events?'
  it 'should provide helpful information if you fuck up the DSL'
  it 'should specifically raise errors when you forget :transitions_to'
end