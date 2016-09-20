RSpec::Matchers.define :have_persisted_state do |state|
  match do |model|
    other = model.class.find(model.id)

    state.to_s == other.read_attribute(model.class.workflow_column)
  end

  failure_message do |model|
    "expected #{model} to have persisted workflow state: #{state}"
  end

  failure_message_when_negated do |model|
    "expected #{model} not to have persisted workflow state: #{state}"
  end
end

RSpec.shared_context "ActiveRecord Setup", :shared_context => :metadata do
  def exec(sql)
    ActiveRecord::Base.connection.execute sql
  end

  before do
    ActiveRecord::Base.establish_connection(
      :adapter => "sqlite3",
      :database  => ":memory:" #"tmp/test"
    )

    # eliminate ActiveRecord warning. TODO: delete as soon as ActiveRecord is fixed
    ActiveRecord::Base.connection.reconnect!
  end

  after do
    ActiveRecord::Base.connection.disconnect!
  end

end
