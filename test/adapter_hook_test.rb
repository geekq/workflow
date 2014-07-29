require File.join(File.dirname(__FILE__), 'test_helper')
require 'workflow'
class AdapterHookTest < ActiveRecordTestCase
  test 'hook to choose adapter' do

    ActiveRecord::Schema.define do
      create_table(:examples) { |t| t.string :workflow_state }
    end

    class DefaultAdapter < ActiveRecord::Base
      self.table_name = :examples
      include Workflow
      workflow do
        state(:initial) { event :progress, :transitions_to => :last }
        state(:last)
      end
    end

    class ChosenByHookAdapter < ActiveRecord::Base
      self.table_name = :examples
      attr_reader :foo
      def self.workflow_adapter
        Module.new do
          def load_workflow_state
            @foo if defined?(@foo)
          end
          def persist_workflow_state(new_value)
            @foo = new_value
          end
        end
      end

      include Workflow
      workflow do
        state(:initial) { event :progress, :transitions_to => :last }
        state(:last)
      end
    end

    default = DefaultAdapter.create
    assert default.initial?
    default.progress!
    assert default.last?
    assert DefaultAdapter.find(default.id).last?, 'should have persisted via ActiveRecord'

    hook = ChosenByHookAdapter.create
    assert hook.initial?
    hook.progress!
    assert_equal hook.foo, 'last', 'should have "persisted" with custom adapter'
    assert ChosenByHookAdapter.find(hook.id).initial?, 'should not have persisted via ActiveRecord'
  end
end
