module Workflow
  class Configuration
    attr_accessor :persist_workflow_state_immediately, :touch_on_update_column

    def initialize
      self.persist_workflow_state_immediately = true
      self.touch_on_update_column = false
    end
  end
end
