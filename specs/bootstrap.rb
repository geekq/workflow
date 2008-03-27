require "#{File.dirname(__FILE__)}/../workflow"

module Recorder
  
  def record(n)
    @records ||= []
    @records << n
  end
  
  def records
    @records or []
  end
  
end