require 'rubygems'
require 'test/unit'

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


