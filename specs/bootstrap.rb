require "#{File.dirname(__FILE__)}/../state_machine"

module Recorder
  
  def record(n)
    @records ||= []
    @records << n
  end
  
  def records
    @records or []
  end
  
end