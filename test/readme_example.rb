require 'workflow'
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

article = Article.new
article.accepted? # => false
article.new? # => true
article.submit!
article.review!

puts article.current_state # => being_reviewed


class Article
  def reject
    puts "send email to the author here explaining the reason for the rejection"
  end
end

article.reject! # will cause a state transition, would persist the new
  # state (if inherited from ActiveRecord), and invoke the callback -
  # send email to the author.
