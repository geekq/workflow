require File.join(File.dirname(__FILE__), 'test_helper')
require 'workflow'

class OnErrorTest < Test::Unit::TestCase
  # A class that does not handle errors in an error block
  class NoErrorBlock
    include Workflow
    workflow do
      state :first do
        event :forward, :transitions_to => :second do
          raise "This is some random runtime error"
        end
      end
      state :second
    end
  end

  # A class that handles errors in an error block
  class ErrorBlock
    attr_reader :errors

    def initialize
      @errors = {}
    end

    include Workflow
    workflow do
      state :first do
        event :forward, :transitions_to => :second do
          raise "This is some random runtime error"
        end
      end
      state :second
      on_error { |error, from, to, event, *args| @errors.merge!({:error => error.class, :from => from, :to => to, :event => event, :args => args}) }
    end
  end


  test 'that an exception is raised if there is no associated on_error block' do
    flow = NoErrorBlock.new
    assert_raise( RuntimeError, "This is some random runtime error" ) { flow.forward! }
    assert_equal(true, flow.first?)
  end
  
  test 'that on_error block is called when an exception is raised and the transition is halted' do
    flow = ErrorBlock.new
    assert_nothing_raised { flow.forward! }
    assert_equal({:error => RuntimeError, :from=>:first, :to=>:second, :event=>:forward, :args=>[]}, flow.errors)
    # transition should not happen
    assert_equal(true, flow.first?)
  end
end