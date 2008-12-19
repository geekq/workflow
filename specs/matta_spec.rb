require "#{File.dirname(__FILE__)}/bootstrap"

class Matta
  include Workflow
end

class SuperMatta < Matta
end

describe "matta's inheritence problem" do
  setup do
    Matta.class_eval do 
      workflow do
        state :sleeping do
          event :wake_up, :transitions_to => :awake
        end
        state :awake do
          event :go_to_sleep, :transitions_to => :sleeping
        end
      end
    end
  end

  it 'works so matta can keep working!' do
    @matta = SuperMatta.new
    @matta.state.should == :sleeping
    @matta.wake_up
    @matta.state.should == :awake
    @matta.go_to_sleep
    @matta.state.should == :sleeping
  end
end
