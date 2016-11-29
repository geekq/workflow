require File.join(File.dirname(__FILE__), 'test_helper')
require 'workflow'
class AdvanceExamplesTest < ActiveRecordTestCase
  def setup
    super

    ActiveRecord::Schema.define do
      create_table :article_with_transactional_transitions do |t|
        t.string :title
        t.string :body
        t.string :blame_reason
        t.string :reject_reason
        t.string :workflow_state
        t.string :type
      end
    end
  end

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
      state :accepted do
      end
      state :rejected do
      end
    end
  end

  class ArticleWithTransactionalTransition < ActiveRecord::Base
    include Workflow
    attr_accessor :rolled_back
    def set_rollback
      self.rolled_back = true
    end
    after_rollback :set_rollback
    workflow transactional: true do
      on_transition do |from, to, triggering_event, updated_attributes, *other_args|
        self.attributes = updated_attributes if updated_attributes
        self.save!
      end

      after_transition do |from, to, triggering_event, updated_attributes, *other_args|
        raise "Major Error" if self.title == "Invalid Title"
      end

      state :new do
        event :submit, transitions_to: :awaiting_review
      end
      state :awaiting_review
    end
  end

  test '#63 undoing event - automatically add revert events for every defined event' do
    # also see https://github.com/geekq/workflow/issues/63
    spec = Article.workflow_spec
    spec.state_names.each do |state_name|
      state = spec.states[state_name]

        (state.events.flat.reject {|e| e.name.to_s =~ /^revert_/ }).each do |event|
          event_name = event.name
          revert_event_name = "revert_" + event_name.to_s

          # Add revert events
          spec.states[event.transitions_to.to_sym].events.push(
            revert_event_name,
            Workflow::Event.new(revert_event_name, state)
          )

          # Add methods for revert events
          Article.module_eval do
            define_method "#{revert_event_name}!".to_sym do |*args|
              process_event!(revert_event_name, *args)
            end
            define_method "can_#{revert_event_name}?" do
              return self.current_state.events.include?(revert_event_name)
            end
          end

        end
    end

    a = Article.new
    assert(a.new?, "should start with the 'new' state")
    a.submit!
    assert(a.awaiting_review?, "should now be in 'awaiting_review' state")
    assert_equal(['revert_submit', 'review'], a.current_state.events.keys.map(&:to_s).sort)
    a.revert_submit! # this method is added by our meta programming magic above
    assert(a.new?, "should now be back in the 'new' state")
  end

  test '#92 Load workflow specification' do
    c = Class.new
    c.class_eval do
      include Workflow
    end

    # build a Specification (you can load it from yaml file too)
    myspec = Workflow::Specification.new do
      state :one do
        event :dynamic_transition, :transitions_to => :one_a
      end
      state :one_a
    end

    c.send :assign_workflow, myspec

    a = c.new
    a.dynamic_transition!(1)
    assert a.one_a?, 'Expected successful transition to a new state'
  end

  test "Transactional Behavior Unchanged In Absence Of Error" do
    a = ArticleWithTransactionalTransition.create
    assert_equal nil, a.title
    a.process_event! :submit, {title: 'Article Title'}
    assert_equal 'Article Title', a.title
    assert !a.title_changed?
  end

  test "Changes Rolled Back On Error For Transactional Workflow" do
    a = ArticleWithTransactionalTransition.create
    assert_raise RuntimeError, "Major Error" do
      a.process_event! :submit, {title: 'Invalid Title'}
    end
    assert_equal 'Invalid Title', a.title # Note that the title was set
    assert a.rolled_back
    a.reload
    assert_nil a.title # But the change was not persisted.
  end
end
