require 'spec_helper'

RSpec.describe "Multiple Workflows" do
  before do
    ActiveRecord::Schema.define do
      create_table :bookings do |t|
        t.string :title, :null => false
        t.string :workflow_state
        t.string :workflow_type
      end
    end
    exec "INSERT INTO bookings(title, workflow_state, workflow_type) VALUES('booking1', 'initial', 'workflow_1')"
    exec "INSERT INTO bookings(title, workflow_state, workflow_type) VALUES('booking2', 'initial', 'workflow_2')"
  end

  class Booking < ActiveRecord::Base

    include Workflow

    def initialize_workflow
      # define workflow per object instead of per class
      case workflow_type
      when 'workflow_1'
        class << self
          workflow do
            state :initial do
              event :progress, :transitions_to => :last
            end
            state :last
          end
        end
      when 'workflow_2'
        class << self
          workflow do
            state :initial do
              event :progress, :transitions_to => :intermediate
            end
            state :intermediate
            state :last
          end
        end
      end
    end

    def metaclass; class << self; self; end; end

    def workflow_spec
      metaclass.workflow_spec
    end
  end

  let(:booking1) {Booking.find_by title: 'booking1'}
  let(:booking2) {Booking.find_by title: 'booking2'}

  before do
    booking1.initialize_workflow
    booking2.initialize_workflow
  end

  describe "Workflow Type 1" do
    subject {booking1}
    it {is_expected.to be_initial}
    it "should progress directly to :last" do
      subject.progress!
      expect(subject).to be_last
    end
    it "should have access to its workflow state" do
      expect(subject.workflow_spec).not_to be_nil
    end
    it "should have two valid states" do
      expect(subject.workflow_spec.states.length).to eq 2
    end
  end

  describe "Workflow Type 2" do
    subject {booking2}
    it {is_expected.to be_initial}
    it "should progress directly to :last" do
      subject.progress!
      expect(subject).not_to be_last
      expect(subject).to be_intermediate
    end
    it "should have access to its workflow state" do
      expect(subject.workflow_spec).not_to be_nil
    end
    it "should have two valid states" do
      expect(subject.workflow_spec.states.length).to eq 3
    end
    it "should persist the workflow state" do
      subject.progress!
      booking = Booking.find(subject.id)
      booking.initialize_workflow
      expect(booking).to be_intermediate
    end
  end


  class Object
    # The hidden singleton lurks behind everyone
    def metaclass; class << self; self; end; end
  end


end
