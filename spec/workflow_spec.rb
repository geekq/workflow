require "spec_helper"

RSpec.shared_examples "Basic Database Operations" do
  it "should be shippable" do
    expect {
      subject.ship!
    }.to change {
      subject.class.find(subject.id)[subject.class.workflow_column]
    }.from('accepted').to('shipped')
  end

  it 'persists workflow_state in the db and reload' do
    expect(subject).to have_persisted_state(:accepted)
    expect(subject).to be_accepted

    subject.ship!
    expect(subject).to have_persisted_state(:shipped)
    subject.reload
    expect(subject).to be_shipped
  end

  it "should have the expected workflow column" do
    expect(subject.class.workflow_column).to eq(expected_workflow_column)
  end

  let(:workflow_state_names) {
    subject.class.workflow_spec.states.map(&:name).map{|n| n.to_s}.to_set
  }

  it 'can access workflow specification' do
    expect(subject.class.workflow_spec.states.length).to eq 3
    expect(workflow_state_names).to eq(Set.new ['submitted', 'accepted', 'shipped'])
  end

  it "can access current state" do
    expect(subject).to be_accepted
    expect(subject.current_state.events.length).to eq 1
  end

  describe "When the initial state is not specified" do
    let(:order) {subject.class.create(title: 'new object')}
    it "Automatically sets the initial state." do
      expect(order).to have_persisted_state(:submitted)
    end
  end

  it "Raises an exception for invalid state transition requested" do
    expect(subject).to be_accepted
    expect {
      subject.accept!
    }.to raise_error(Workflow::NoTransitionAllowed, "There is no event accept defined for the accepted state")
  end

end

RSpec.describe Workflow do
  it "has a version number" do
    expect(Workflow::VERSION).not_to be nil
  end

  class Order < ActiveRecord::Base
    include Workflow
    workflow do
      state :submitted do
        on :accept, to: :accepted, :meta => {:weight => 8}
      end
      state :accepted do
        on :ship, to: :shipped
      end
      state :shipped
    end
  end

  class LegacyOrder < ActiveRecord::Base
    include Workflow

    workflow_column :foo_bar # use this legacy database column for persistence

    workflow do
      state :submitted do
        on :accept, to: :accepted, :meta => {:weight => 8}
      end
      state :accepted do
        on :ship, to: :shipped
      end
      state :shipped
    end
  end

  before do
    ActiveRecord::Schema.define do
      create_table :orders do |t|
        t.string :title, :null => false
        t.string :workflow_state
      end
    end

    ActiveRecord::Schema.define do
      create_table :legacy_orders do |t|
        t.string :title, :null => false
        t.string :foo_bar
      end
    end

    exec "INSERT INTO legacy_orders(title, foo_bar) VALUES('some order', 'accepted')"

    ActiveRecord::Schema.define do
      create_table :images do |t|
        t.string :title, :null => false
        t.string :state
        t.string :type
      end
    end
  end

  describe "Model with standard workflow_state column" do
    subject {Order.create title: 'some order', workflow_state: 'accepted'}
    let(:expected_workflow_column) {:workflow_state}
    it_has_the_behavior_of "Basic Database Operations"

  end

  describe "Model with custom workflow column" do
    subject {LegacyOrder.create title: 'some order', foo_bar: 'accepted'}
    let(:expected_workflow_column) {:foo_bar}
    it_has_the_behavior_of "Basic Database Operations"
  end

  describe "Some Callbacks" do
    subject do
      klass = Class.new
      klass.class_eval do
        include Workflow
        def before_transition1; end
        def after_transition2; end

        before_transition :before_transition1
        after_transition  :after_transition2

        workflow do
          state :new do
            on :age, to: :old
          end
          state :old
        end
      end
      klass.new
    end

    it "calls the callbacks" do
      expect(subject).to receive(:before_transition1)
      expect(subject).to receive(:after_transition2)
      subject.age!
    end
  end

  def new_workflow_class(sup_class=Object, &block)
    c = Class.new(sup_class)
    c.class_eval do
      include Workflow
      workflow &block
    end
    c
  end

  describe "Event Meta Info" do
    subject {
      new_workflow_class do
        state :main, :meta => {:importance => 8}
        state :supplemental, :meta => {:importance => 1}
      end
    }
    let(:state_importance) {subject.workflow_spec.find_state(:supplemental).meta[:importance]}
    it "should be able to read the meta" do
      expect(state_importance).to eq 1
    end
  end

  describe "Initial State" do
    subject {
      new_workflow_class do
        state :one; state :two
      end.new
    }
    it {is_expected.to be_one}
  end

  describe "When initial state stored as nil" do
    before do
      exec "INSERT INTO orders(title, workflow_state) VALUES('nil state', NULL)"
    end
    subject {Order.find_by title: 'nil state'}
    it {is_expected.to be_submitted}
    it {is_expected.not_to be_shipped}
  end

  it "implicit transition callback" do
    klass = new_workflow_class do
      state :one do
        on :my_transition, to: :two
      end
      state :two
    end
    klass.class_eval do
      def my_transition(args)
        args.my_tran
      end
    end
    subj = klass.new
    expect(subj).to receive(:my_transition)
    subj.my_transition!

  end

  describe "Non-public transition callbacks are allowed" do
    let(:base_class) do
      new_workflow_class do
        state :new do
          on :assign, to: :assigned
        end
        state :assigned
      end
    end

    describe "When callback is public" do
      subject {
        base_class.class_eval do
          def assign
          end
        end
        base_class.new
      }
      it "works" do
        expect(subject).to receive(:assign)
        subject.assign!
      end
    end

    describe "When callback is protected" do
      subject {
        base_class.class_eval do
          protected
          def assign
          end
        end
        base_class.new
      }
      it "works" do
        expect(subject).to receive(:assign)
        subject.assign!
      end
    end

    describe "When callback is private" do
      subject {
        base_class.class_eval do
          private
          def assign
          end
        end
        base_class.new
      }
      it "works" do
        expect(subject).to receive(:assign)
        subject.assign!
      end
    end

  end

  describe "Single Table Inheritance" do
    let(:base_class) {Class.new(Order)}
    subject {base_class.new}
    it {is_expected.to be_submitted}
    it {is_expected.not_to be_accepted}

    describe "When parent has changed workflow_state column" do
      let(:subclass) {Class.new(LegacyOrder)}
      let(:sub_subclass) {Class.new(subclass)}
      it "should have the same workflow column" do
        expect(subclass.workflow_column).to eq(LegacyOrder.workflow_column)
        expect(sub_subclass.workflow_column).to eq(LegacyOrder.workflow_column)
      end

      subject {sub_subclass.new}
      it {is_expected.to be_submitted}
    end
  end

  describe "When workflow is overridden in subclass" do
    let(:subclass) {
      new_workflow_class(Order) do
        state :start_big
      end
    }
    subject {subclass.new}

    it {is_expected.to be_start_big}
  end

  describe "#halt" do
    subject {
      klass = new_workflow_class do
        state :young do
          on :age, to: :old
          on :reject, to: :old
        end
        state :old
      end
      klass.class_eval do
        def age(by=1)
          halt 'too fast' if by > 100
        end
        def reject(reason)
          halt! 'We do not reject articles unless the reason is important' \
            unless reason =~ /important/i
          self.too_far = "This line should not be executed"
        end
      end
      klass.new
    }

    it "stops the transition" do
      expect(subject).to be_young
      subject.age! 120
      expect(subject).to be_young
      expect(subject.halted_because).to eq('too fast')
    end

    describe "#halt!" do
      it "raises an exception" do
        expect {subject.reject!('it is stupid')}.to raise_error(Workflow::TransitionHaltedError)
      end
    end
  end

  describe "#can_fire_event? methods" do
    subject do
      new_workflow_class do
        state :newborn do
          on :go_to_school, to: :schoolboy
        end
        state :schoolboy do
          on :go_to_college, to: :student
        end
        state :student
        state :street
      end.new
    end

    it "should be able to do the events from current state" do
      expect(subject).to be_newborn
      expect(subject.can_go_to_school?).to be_truthy
    end
    it "should not be able to do the events from other states" do
      expect(subject).not_to be_schoolboy
      expect(subject.can_go_to_college?).to be_falsey
    end

    describe "With conditions" do
      subject do
        klass = new_workflow_class do
          state :off do
            on :turn_on do
              to :on, if: :sufficient_battery_level?
              to :low_battery, if: -> (obj) {obj.battery > 0}
            end
          end
          state :on
          state :low_battery
        end
        klass.class_eval do
          attr_accessor :battery

          def sufficient_battery_level?
            battery > 10
          end
        end
        klass.new
      end

      describe "when the condition is not met" do
        it "should not be able to transition" do
          subject.battery = 0
          expect(subject.can_turn_on?).to be_falsey
        end
      end
      describe "when the condition is met" do
        it "will turn on when battery is sufficient" do
          subject.battery = 50
          expect(subject.can_turn_on?).to be_truthy
          subject.turn_on!
          expect(subject).to be_on
        end

        it "will power on to low battery if the battery is low but not zero" do
          subject.battery = 5
          expect(subject.can_turn_on?).to be_truthy
          subject.turn_on!
          expect(subject).to be_low_battery
        end
      end

    end
  end
end
