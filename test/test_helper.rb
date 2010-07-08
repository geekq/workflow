require 'rubygems'
require 'test/unit'
require 'active_record'

class << Test::Unit::TestCase
  def test(name, &block)
    test_name = :"test_#{name.gsub(' ','_')}"
    raise ArgumentError, "#{test_name} is already defined" if self.instance_methods.include? test_name.to_s
    if block
      define_method test_name, &block
    else
      puts "PENDING: #{name}"
    end
  end
end

class ActiveRecordTestCase < Test::Unit::TestCase
  def exec(sql)
    ActiveRecord::Base.connection.execute sql
  end

  def setup
    ActiveRecord::Base.establish_connection(
      :adapter => "sqlite3",
      :database  => ":memory:" #"tmp/test"
    )

    # eliminate ActiveRecord warning. TODO: delete as soon as ActiveRecord is fixed
    ActiveRecord::Base.connection.reconnect!
  end

  def teardown
    ActiveRecord::Base.connection.disconnect!
  end

  def default_test
  end
end

