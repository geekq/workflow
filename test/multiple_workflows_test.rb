require File.join(File.dirname(__FILE__), 'test_helper')
class MultipleWorkflowsTest < ActiveRecordTestCase

  test 'multiple workflows' do

    ActiveRecord::Schema.define do
      create_table :bookings do |t|
        t.string :title, :null => false
        t.string :workflow_state
        t.string :workflow_type
      end
    end

    exec "INSERT INTO bookings(title, workflow_state, workflow_type) VALUES('booking1', 'initial', 'workflow_1')"
    exec "INSERT INTO bookings(title, workflow_state, workflow_type) VALUES('booking2', 'initial', 'workflow_2')"

    class Booking < ActiveRecord::Base
      def initialize_workflow
        # define workflow per object instead of per class
        case workflow_type
        when 'workflow_1'
          class << self
            include Workflow
            workflow do
              state :initial do
                event :progress, :transitions_to => :last
              end
              state :last
            end
          end
        when 'workflow_2'
          class << self
            include Workflow
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
    end

    booking1 = Booking.find_by_title('booking1')
    booking1.initialize_workflow

    booking2 = Booking.find_by_title('booking2')
    booking2.initialize_workflow

    assert booking1.initial?
    booking1.progress!
    assert booking1.last?, 'booking1 should transition to the "last" state'

    assert booking2.initial?
    booking2.progress!
    assert booking2.intermediate?, 'booking2 should transition to the "intermediate" state'
  end

end
