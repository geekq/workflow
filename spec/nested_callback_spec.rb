require 'spec_helper'

RSpec.describe "Nested Callbacks" do
  def define_all_callbacks
    workflow_class.class_eval do
      [:transition, :enter, :exit].each do |name|
        [:before, :after].each do |callback|
          method = "#{callback}_#{name}".to_sym
          send method do
            callbacks << method
          end
        end
        method = "around_#{name}".to_sym
        send method do |obj, proc|
          callbacks << method
          proc.call
        end
      end
    end
  end

  let(:workflow_class) do
    klass = new_workflow_class do
      state :initial do
        on :start, to: :somewhere_else
        on :dope, to: :somewhere_else
      end
      state :somewhere_else do
        on :start, to: :final
        on :goto_final, to: :final
      end
      state :final
    end
    klass.class_eval do
      attr_accessor :callbacks
      def initialize; @callbacks = []; end
    end
    klass
  end
  subject {
    workflow_class.new
  }

  describe "Aborting callback sequence" do
    before do
      define_all_callbacks
      workflow_class.class_eval do
        attr_accessor :something
        def abort_callback
          throw :abort
        end
        before_exit :abort_callback, only: :somewhere_else
      end
    end

    describe "when making unaffected transitions" do
      it "should still be able to progress" do
        subject.start!
        expect(subject).to be_somewhere_else
      end
    end

    describe "when trying to leave the :somewhere_else state" do
      before do
        subject.start!
        subject.callbacks.clear
        expect(subject).to be_somewhere_else
      end
      it "should fail the transition" do
        subject.goto_final!
        expect(subject).to be_somewhere_else
      end
      it "should not run the rest of the callbacks" do
        subject.goto_final!
        expect(subject.callbacks).to eq [:before_transition, :around_transition, :before_exit, :around_exit]
      end
    end

    describe "Skip before_exit and fail another way" do
      before do
        workflow_class.class_eval do
          skip_before_exit :abort_callback, only: :somewhere_else
          before_exit :abort_callback, only: :somewhere_else, unless: "something.nil?"
        end
      end
      it "should succeed the transition" do
        subject.start!
        expect(subject.something).to be_nil
        subject.goto_final!
        expect(subject).to be_final
      end
      describe "If the new string condition is met" do
        it "should fail the transition" do
          subject.start!
          subject.something = "anything"
          subject.goto_final!
          expect(subject).to be_somewhere_else
        end
      end
    end
  end

  describe "Callbacks on a given state exit" do
    before do
      workflow_class.class_eval do
        before_exit only: :initial do
          callbacks << :initial
        end
      end
    end

    it "should call the callback when leaving by the :start! event" do
      subject.start!
      expect(subject.callbacks).to eq([:initial])
    end

    it "should call the callback when leaving by the :dope! event" do
      subject.dope!
      expect(subject.callbacks).to eq([:initial])
    end
  end

  describe "Callbacks on a given state ENTRY" do
    before do
      workflow_class.class_eval do
        before_enter only: :final do
          callbacks << :final
        end
      end
    end

    it "should call the callback once when entering the :final state" do
      subject.dope!
      subject.start!
      expect(subject.callbacks).to eq([:final])
    end

    it "should call the callback when leaving by the :dope! event" do
      subject.start!
      subject.start!
      expect(subject.callbacks).to eq([:final])
    end
  end

  describe "Callbacks on a given event name" do
    before do
      workflow_class.class_eval do
        before_transition only: :start do
          callbacks << :start
        end
        before_transition only: :dope do
          callbacks << :dope
        end
      end
    end

    describe "When the start is called twice" do
      it "should run the callback twice" do
        subject.start!
        expect(subject).to be_somewhere_else
        subject.start!
        expect(subject).to be_final
        expect(subject.callbacks).to eq [:start, :start]
      end
    end

    describe "when the start is only called once" do
      it "should run the callback twice" do
        subject.dope!
        expect(subject).to be_somewhere_else
        subject.start!
        expect(subject).to be_final
        expect(subject.callbacks).to eq [:dope, :start]
      end
    end
  end

  describe "Callback Order" do
    before do
      define_all_callbacks
    end
    it "should call the callbacks in a given order" do
      a = workflow_class.new
      a.start!
      expect(a.callbacks).to eq [:before_transition, :around_transition, :before_exit, :around_exit, :before_enter, :around_enter, :after_enter, :after_exit, :after_transition]
    end
  end
end
