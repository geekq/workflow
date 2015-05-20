require File.join(File.dirname(__FILE__), 'test_helper')
require 'workflow'

class EnumValuesTest < ActiveRecordTestCase
  test 'that the value of the state is persisted instead of the name' do
  
    ActiveRecord::Schema.define do
      create_table(:active_enum_flows) { |t| t.integer :state }
    end

    class ActiveEnumFlow < ActiveRecord::Base
      include Workflow
      workflow_column :state

      workflow do
        state :first, 1 do
          event :forward, :transitions_to => :second
        end
        state :second, 2 do
          event :back, :transitions_to => :first
        end
      end
    end

    flow = ActiveEnumFlow.create
    flow.forward!
    assert flow.state == 2
    assert flow.second?
  end
end
