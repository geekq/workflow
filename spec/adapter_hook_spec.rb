require 'spec_helper'
RSpec.describe "Adapter Hooks" do
  class DefaultAdapter < ActiveRecord::Base
    self.table_name = :examples
    include Workflow
    workflow do
      state(:initial) { on :progress, to: :last }
      state(:last)
    end
  end

  class ChosenByHookAdapter < ActiveRecord::Base
    self.table_name = :examples
    attr_reader :foo
    def self.workflow_adapter
      Module.new do
        def load_workflow_state
          @foo if defined?(@foo)
        end
        def persist_workflow_state(new_value)
          @foo = new_value
        end
      end
    end

    include Workflow
    workflow do
      state(:initial) { on :progress, to: :last }
      state(:last)
    end
  end
  # 
  # class Article < ActiveRecord::Base
  #   include Workflow
  #   include Workflow::CanCan
  #
  #   workflow do
  #     state :new do
  #       on :review, to: :being_reviewed
  #
  #       on :submit do
  #         to :submitted,
  #           if:     [ "name == 'The Dude'", :abides?, -> (rug) {rug.tied_the_room_together?}],
  #           unless: :nihilist?
  #
  #         to :trash, unless: :body?
  #         to :another_place do |article|
  #           article.foo?
  #         end
  #       end
  #     end
  #   end
  # end

  before do
    ActiveRecord::Schema.define do
      create_table(:examples) { |t| t.string :workflow_state }
    end
  end

  describe "Using the default adapter" do
    subject {DefaultAdapter.create}
    it {is_expected.to be_initial}
    it "should be able to progress" do
      subject.progress!
      expect(subject).to have_persisted_state(:last)
    end
  end

  describe "Using custom adapter" do
    subject {ChosenByHookAdapter.create}
    it {is_expected.to be_initial}

    it "should progress with custom functionality" do
      subject.progress!
      expect(subject.foo).to eq :last
      expect(subject).not_to have_persisted_state('last')
    end
  end
end
