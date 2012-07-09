require 'rspec'
require 'workflow'

class Article

  include Workflow
  workflow do
    state :new do
      event :submit, :transitions_to => :awaiting_review
    end
    state :awaiting_review do
      event :review, :transitions_to => :being_reviewed
      event :impossible_event, :transitions_to => :impossible_state, :if => [Proc.new{|t| t.false_value}, "error message"]
      event :inevitable_event, :transitions_to => :inevitable_state, :if => Proc.new{|t| t.true_value}
    end
    state :being_reviewed do
      event :accept, :transitions_to => :accepted
      event :reject, :transitions_to => :rejected
    end
    state :accepted
    state :rejected
    state :impossible_state
    state :inevitable_state
  end

  def false_value
    false
  end

  def true_value
    true
  end

end

