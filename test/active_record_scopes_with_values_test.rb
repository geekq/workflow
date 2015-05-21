require File.join(File.dirname(__FILE__), 'test_helper')

$VERBOSE = false
require 'active_record'
require 'sqlite3'
require 'workflow'

ActiveRecord::Migration.verbose = false

class EnumArticle < ActiveRecord::Base
  include Workflow

  workflow do
    state :new, 1 do
      event :accept, transitions_to: :accepted
    end
    state :accepted, 3
  end
end

class ActiveRecordScopesWithValuesTest < ActiveRecordTestCase

  def setup
    super

    ActiveRecord::Schema.define do
      create_table :enum_articles do |t|
        t.string :title
        t.string :body
        t.string :blame_reason
        t.string :reject_reason
        t.integer :workflow_state
      end
    end
  end

  test 'have "with_new_state" scope' do
    assert_respond_to EnumArticle, :with_new_state
  end

  test '"with_new_state" selects matching value' do
    article = EnumArticle.create
    assert_equal(article.workflow_state, 1)
    assert_equal(EnumArticle.with_new_state.all, [article])
  end

  test 'have "with_accepted_state" scope' do
    assert_respond_to EnumArticle, :with_accepted_state
  end

  test '"with_accepted_state" selects matching values' do
    article = EnumArticle.create
    article.accept!
    assert_equal(EnumArticle.with_accepted_state.all, [article])
  end

  test 'have "without_new_state" scope' do
    assert_respond_to EnumArticle, :without_new_state
  end

  test '"without_new_state" filters matching value' do
    article = EnumArticle.create
    article.accept!
    assert_equal(article.workflow_state, 3)
    assert_equal(EnumArticle.without_new_state, [article])
  end

  test 'have "without_accepted_state" scope' do
    assert_respond_to EnumArticle, :without_accepted_state
  end

  test '"without_accepted_state" filters matching value' do
    article = EnumArticle.create
    assert_equal(article.workflow_state, 1)
    assert_equal(EnumArticle.without_accepted_state, [article])
  end

end

