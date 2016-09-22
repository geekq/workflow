require 'spec_helper'

RSpec.describe Workflow::Event do
  class NewWorldOrder < ActiveRecord::Base
    include Workflow

    before_enter :shipping, only: :shipped

    def title_equals_foobar?
      title == 'foobar'
    end

    def title_equals_foobaz?
      title == 'Foobaz'
    end

    def title_equals_please?
      title == 'PLEASE'
    end

    def title_still_equals_please?
      title == 'PLEASE'
    end

    workflow do
      state :string_conditions do
        on :submit do
          to :state1, if: "title == 'foobar'"
          to :state2, if: "title == 'Foobaz'"
          to :state3, unless: "title == 'PLEASE'"
          to :state4
        end
      end

      state :block_conditions do
        on :submit do
          to :state1 do
            title == 'foobar'
          end
          to :state2 do
            title == 'Foobaz'
          end
          to :state3 do
            title != 'PLEASE'
          end
          to :state4
        end
      end

      state :proc_conditions do
        on :submit do
          to :state1, if: ->(){title=='foobar'}
          to :state2, if: ->(){title == 'Foobaz'}
          to :state3, unless: ->(){title == 'PLEASE'}
          to :state4
        end
      end

      state :method_conditions do
        on :submit do
          to :state1, if: :title_equals_foobar?
          to :state2, if: :title_equals_foobaz?
          to :state3, unless: :title_equals_please?
          to :state4
        end
      end

      state :array_conditions do
        on :submit do
          to :state1, if: [:title_equals_foobaz?, "false"]
          to :state2, if: [:title_equals_foobaz?, "true"]
          to :state3, unless: [:title_equals_please?, :title_still_equals_please?]
          to :state4
        end
      end

      state :mixed_conditions do
        on :submit do
          to :state1, if: [:title_equals_foobaz?, "true"] do
            false
          end
          to :state2, if: "true" do
            title_equals_foobaz?
          end
          to :state3, unless: :title_equals_please? do
            !title_still_equals_please?
          end
          to :state4
        end
      end

      state :state1
      state :state2
      state :state3
      state :state4
    end
  end

  before do
    ActiveRecord::Schema.define do
      create_table :new_world_orders do |t|
        t.string :title
        t.string :workflow_state
      end
    end
  end

  RSpec.shared_examples "Conditional Evaluation" do |workflow_state|
    subject {NewWorldOrder.create workflow_state: workflow_state}

    it "Catches the correct :if condition" do
      subject.title = 'Foobaz'
      subject.submit!
      expect(subject).to be_state2
    end
    it "Catches the :unless condition" do
      subject.title = 'Random'
      subject.submit!
      expect(subject).to be_state3
    end
    it "Falls through to the catchall condition" do
      subject.title = 'PLEASE'
      subject.submit!
      expect(subject).to be_state4
    end
  end

  describe "Block conditions" do
    it_has_the_behavior_of "Conditional Evaluation", 'block_conditions'
  end

  describe "String Conditions" do
    it_has_the_behavior_of "Conditional Evaluation", 'string_conditions'
  end

  describe "Proc Conditions" do
    it_has_the_behavior_of "Conditional Evaluation", 'proc_conditions'
  end

  describe "Method Conditions" do
    it_has_the_behavior_of "Conditional Evaluation", 'method_conditions'
  end

  describe "Array Conditions" do
    it_has_the_behavior_of "Conditional Evaluation", 'array_conditions'
  end

  describe "Mixed Conditions" do
    it_has_the_behavior_of "Conditional Evaluation", 'mixed_conditions'
  end
end
