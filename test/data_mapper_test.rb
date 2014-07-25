require 'data_mapper'
require 'workflow'
require 'pry'

class User
  include DataMapper::Resource
  include Workflow

  property :id,    Serial
  property :workflow_state, String
  property :email, String

  workflow do
    state :submitted do
      event :activate_via_link, :transitions_to => :proved_email
    end
    state :proved_email
  end
end


class CouchtinyExample < Test::Unit::TestCase

  def setup
    DataMapper.setup(:default, 'sqlite::memory:')
    DataMapper.finalize
    DataMapper.auto_migrate!
  end

  test 'DataMapper persistence' do
    user = User.new :email => 'manya@example.com'

    user.save
    assert user.submitted?

    user.activate_via_link!
    assert user.proved_email?

    reloaded_user = User.get user.id
    assert reloaded_user.proved_email?, 'Reloaded user should have the desired workflow state'
  end
end
