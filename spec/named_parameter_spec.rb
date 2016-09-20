require 'spec_helper'

RSpec.describe "Named Parameters" do
  class HasMethods
    include Workflow
    attr_accessor :nice, :cool, :dope
    def start0
    end
    def start1(a)
    end
    def start2(a, b)
    end
    def start3(a, b, c)
    end
    def start_minus1(*a)
    end
    def start_minus2(a, *b)
    end
    def start_minus3(a, b, *c)
    end
    before_transition do |obj|
      obj.nice = transition_context.nice
      obj.cool = transition_context.cool
      obj.dope = transition_context.dope
    end
    workflow do
      event_args :nice, :cool, :dope
      state :initial do
        event :start0, transitions_to: :started
        event :start1, transitions_to: :started
        event :start2, transitions_to: :started
        event :start3, transitions_to: :started
        event :start_minus1, transitions_to: :started
        event :start_minus2, transitions_to: :started
        event :start_minus3, transitions_to: :started
      end
      state :started
    end
  end
  subject {HasMethods.new}

  describe "Transition context" do
    describe "When used correctly" do
      it "has these values" do
        subject.start_minus3! 'yes', 'no', 'maybe', 'so'
        expect(subject.nice).to eq 'yes'
        expect(subject.cool).to eq 'no'
        expect(subject.dope).to eq 'maybe'
      end
      it "is nil for missing params" do
        subject.start0!
        expect(subject.nice).to be_nil
        expect(subject.cool).to be_nil
        expect(subject.dope).to be_nil
      end
    end

    describe "when called incorrectly" do
      let(:subclass) {Class.new(HasMethods)}
      subject {subclass.new}
      before do
        subclass.before_transition do |obj|
          transition_context.huh?
        end
      end
      it "should raise MethodMissing" do
        expect{subject.start0!}.to raise_error(NoMethodError)
      end
    end
  end
end
