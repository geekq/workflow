require 'spec_helper'

RSpec.describe "Workflow Class Inheritance" do
  class Animal
    include Workflow

    workflow do

      state :conceived do
        event :birth, :transition_to => :born
      end

      state :born do

      end
    end
  end

  class Cat < Animal
    include Workflow
    workflow do

      state :upset do
        event :scratch, :transition_to => :hiding
      end

      state :hiding do

      end
    end
  end

  let(:states) {subject.class.workflow_spec.states.keys}

  describe Animal do
    it "should have these states state" do
      expect(states).to include(:born)
      expect(states).to include(:conceived)
    end

    it "should have a birth event" do
      expect {
        subject.birth!
      }.not_to raise_error
    end

    it "should have the following event processing methods" do
      expect(bang_methods(subject)).to eq(Set.new [:birth!, :halt!, :process_event!])
    end
  end

  describe Cat do
    it "should not have the Animal states" do
      expect(states).not_to include(:born)
      expect(states).not_to include(:conceived)
    end

    it "should have cat states" do
      expect(states).to include(:hiding)
      expect(states).to include(:upset)
    end
    it "should have the following event processing methods" do
      expect(bang_methods(subject)).to eq(Set.new [:halt!, :process_event!, :scratch!])
    end

    it "should not have a birth! method like Animal does" do
      expect {
        subject.birth!
      }.to raise_error(NoMethodError)
    end
  end

  def bang_methods(obj)
    non_trivial_methods = obj.public_methods - Object.public_methods
    methods_with_bang = non_trivial_methods.select { |m| m =~ /!$/ }
    methods_with_bang.map(&:to_sym).to_set
  end
end
