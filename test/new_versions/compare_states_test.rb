require 'test_helper'
require 'workflow'

class ComparableStatesOrder
  include Workflow
  workflow do
    state :submitted do
      event :accept, :transitions_to => :accepted, :meta => {:weight => 8} do |reviewer, args|
      end
    end
    state :accepted do
      event :ship, :transitions_to => :shipped
    end
    state :shipped
  end
end

class CompareStatesTest < Test::Unit::TestCase

  test 'compare states' do
    o = ComparableStatesOrder.new
    o.accept!
    assert_equal :accepted, o.current_state.name
    assert o.current_state == :accepted
    assert o.current_state < :shipped
    assert o.current_state > :submitted
    assert_raise ArgumentError do
      o.current_state > :unknown
    end
  end

end
