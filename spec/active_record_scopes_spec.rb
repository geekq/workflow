require "spec_helper"

RSpec.describe "Active Record Scopes", type: :active_record_examples do
  include_context "ActiveRecord Setup"
  class Article < ActiveRecord::Base
    include Workflow

    workflow do
      state :new
      state :accepted
    end
  end

  before do
    ActiveRecord::Schema.define do
      create_table :articles do |t|
        t.string :title
        t.string :body
        t.string :blame_reason
        t.string :reject_reason
        t.string :workflow_state
      end
    end
  end

  subject {Article}
  it {is_expected.to respond_to(:with_new_state)}
  it {is_expected.to respond_to(:with_accepted_state)}
  it {is_expected.to respond_to(:without_new_state)}
  it {is_expected.to respond_to(:without_accepted_state)}
end
