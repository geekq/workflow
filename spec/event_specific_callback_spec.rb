require 'spec_helper'

RSpec.describe "Event-Specific Callback Method" do
  class HasMethods
    include Workflow

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
    workflow do
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

  describe "no parameters" do
    it "should throw an error if called with params" do
      expect {subject.start0! :nice}.to raise_error(Workflow::CallbackArityError)
    end
    it "should succeed if called with no params" do
      expect {subject.start0!}.not_to raise_error
    end
  end

  describe "one parameter" do
    it "should succeed if called with one params" do
      expect {subject.start1! :a}.not_to raise_error
    end

    it "should throw error when called with none" do
      expect {subject.start1!}.to raise_error(Workflow::CallbackArityError)
    end

    it "should throw error when called with two" do
      expect {subject.start1! :a, :b}.to raise_error(Workflow::CallbackArityError)
    end
  end

  describe "minus three" do
    it "should throw error when called with 1" do
      expect {subject.start_minus3! :a}.to raise_error(Workflow::CallbackArityError)
    end
    it "should succeed if called with two params" do
      expect {subject.start_minus3! :a, :b}.not_to raise_error
    end

    it "should succeed if called with three params" do
      expect {subject.start_minus3! :a, :b, :c}.not_to raise_error
    end

    it "should succeed if called with four params" do
      expect {subject.start_minus3! :a, :b, :c, :d}.not_to raise_error
    end
  end
end
