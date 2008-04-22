%w(rubygems activerecord).each { |lib| require lib }



class Item < ActiveRecord::Base
  
  alias_method :initialize_before_integration, :initialize
  attr_accessor :workflow
  
  def initialize(attributes = nil)
    initialize_before_integration(attributes)
    @workflow = :start # initialize
  end
  
  def after_find
    @workflow = state.to_sym # reconsitute
  end
  
  def before_save
    self.saves += 1
  end
  
  alias_method :before_save_before_integration, :before_save
  
  def before_save
    before_save_before_integration()
    self.state = @workflow.to_s
  end
  
end

require 'test/unit'

class TestTest < Test::Unit::TestCase

  def test_default_values_are_what_we_expect
    @item = Item.new
    assert_nil @item.state
    assert_equal :start, @item.workflow
    assert_equal 0, @item.saves
  end
  
  def test_it_increments_saves_on_each_save
    @item = Item.new
    3.times { @item.save }
    assert_equal 3, @item.saves
  end
  
  def test_it_serializes_workflow_as_string_to_state_on_save
    @item = Item.new
    @item.workflow = :a_workflow
    @item.save
    assert_equal 'a_workflow', @item.state
  end

  def test_it_reconsitutes_workflow_from_state_field
    @item = Item.new
    @item.workflow = :lol_ok
    @item.save
    @item.connection.execute("update items set state = 'err_ok' where id = #{@item.id}")
    @item = Item.find(@item.id)
    assert_equal :err_ok, @item.workflow
  end
  
end