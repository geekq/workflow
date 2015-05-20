class EnumValuesInMemoryTest < ActiveRecordTestCase
  test 'that the value of the state is persisted instead of the name' do 

    class EnumFlow
      attr_reader :workflow_state
      include Workflow

      workflow do
        state :first, 1 do
          event :forward, :transitions_to => :second
        end
        state :second, 2 do
          event :back, :transitions_to => :first
        end
      end
    end

    flow = EnumFlow.new
    flow.forward!
    assert flow.workflow_state == 2
    assert flow.second?
  end
end
