require File.join(File.dirname(__FILE__), 'test_helper')
require 'workflow'

# Example from the README, TODO: integrate other way around via asciidoctor code inclusion
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

class MainTest < Minitest::Test
  test 'reflection' do
    article2 = Article.new
    article2.submit!
    article2.review!
    assert_equal 2, article2.current_state.events.length
    # Please note the usage of `first`, since coditional event transitions can
    # define multiple event definitions with the same name

    # tag::reflect[]
    assert_equal :rejected, article2.current_state.events[:reject].first.transitions_to
    # end::reflect[]
  end
end
