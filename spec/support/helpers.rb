RSpec.shared_context "Shared Helpers", :shared_context => :metadata do
  def new_workflow_class(superklass=Object, &block)
    k = Class.new(superklass)
    k.class_eval do
      include Workflow
      workflow(&block)
    end
    k
  end

  #
  # before do
  #   ActiveRecord::Base.establish_connection(
  #     :adapter => "sqlite3",
  #     :database  => ":memory:" #"tmp/test"
  #   )
  #
  #   # eliminate ActiveRecord warning. TODO: delete as soon as ActiveRecord is fixed
  #   ActiveRecord::Base.connection.reconnect!
  # end
  #
  # after do
  #   ActiveRecord::Base.connection.disconnect!
  # end

end
