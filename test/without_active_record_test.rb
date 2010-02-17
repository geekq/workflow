require File.join(File.dirname(__FILE__), 'test_helper')
require 'workflow'

class WithoutWorkflowTest < Test::Unit::TestCase
  class Article
    include Workflow
    workflow do
      state :new do
        event :submit, :transitions_to => :awaiting_review
      end
      state :awaiting_review do
        event :review, :transitions_to => :being_reviewed
      end
      state :being_reviewed do
        event :accept, :transitions_to => :accepted
        event :reject, :transitions_to => :rejected
      end
      state :accepted
      state :rejected
    end
  end

  def test_readme_example_article
    article = Article.new
    assert article.new?
  end

  test 'better error message on transitions_to typo' do
    assert_raise Workflow::WorkflowDefinitionError do
      Class.new do
        include Workflow
        workflow do
          state :new do
            event :event1, :transitionnn => :next # missing transitions_to target
          end
          state :next
        end
      end
    end
  end

  test 'check transition_to alias' do
    Class.new do
      include Workflow
      workflow do
        state :new do
          event :event1, :transition_to => :next
        end
        state :next
      end
    end
  end
end

