require File.join(File.dirname(__FILE__), 'test_helper')

$VERBOSE = false
require 'active_record'
require 'sqlite3'
require 'workflow'

ActiveRecord::Migration.verbose = false

class EnumArticleHi < ActiveRecord::Base
  include Workflow

  workflow :inline_column_hi do
    state :new, 1 do
      event :accept, transitions_to: :accepted
    end
    state :accepted, 3
  end
end

class InlineColumnTest < ActiveRecordTestCase

  def setup
    super

    ActiveRecord::Schema.define do
      create_table :enum_article_his do |t|
        t.string :title
        t.string :body
        t.string :blame_reason
        t.string :reject_reason
        t.integer :inline_column_hi
      end
    end
  end

  test '"with_new_state" selects matching value' do
    article = EnumArticleHi.create
    assert_equal(article.inline_column_hi, 1)
    article.accept!
    assert_equal(article.inline_column_hi, 3)
  end

  test 'allows passing in state value on create' do
    article = EnumArticleHi.create(inline_column_hi: 3)
    assert_equal(article.inline_column_hi, 3)
  end

  test 'allows passing in state name on create' do
    article = EnumArticleHi.create(inline_column_hi: :accepted)
    assert_equal(article.inline_column_hi, 3)
  end
end

