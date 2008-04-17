module Recorder
  
  @@records = {}
  
  def record(n)
    initialize_records unless records_initialized?
    @@records[self] << n
  end
  
  def records
    initialize_records unless records_initialized?
    @@records[self]
  end
  
  def self.inspect
    @@records.inspect
  end
  
private

  def initialize_records
    @@records[self] ||= []
  end
  
  def records_initialized?
    @@records[self]
  end
  
end

if __FILE__ == $0
  
  require 'test/unit'
  
  class ClassA; end
  class ClassB; end
  class ClassC; include Recorder; end
  
  class RecorderTest < Test::Unit::TestCase
   
    def setup
      @object_a = ClassA.new
      @object_a.extend(Recorder)
      @object_b = ClassB.new
      @object_b.extend(Recorder)
      @object_c = ClassC.new
      @object = @object_a
    end
    
    def test_recorder_can_record_things
      @object.record(1)
      @object.record(2)
      assert_equal [1,2], @object.records
    end
    
    def test_records_are_initialized_to_empty_array
      assert_equal [], @object.records
    end
    
    def test_we_dont_get_record_conflicts_between_classes_or_instances
      @object_a.record(:a)
      @object_b.record(:b)
      assert_equal [:a], @object_a.records
      assert_equal [:b], @object_b.records
    end
    
    def test_it_is_all_good_with_include_as_well
      test_we_dont_get_record_conflicts_between_classes_or_instances
      @object_c.record(:c)
      assert_equal [:c], @object_c.records
    end
    
  end
  
end