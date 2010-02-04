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
end

