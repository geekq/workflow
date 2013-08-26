require File.join(File.dirname(__FILE__), 'test_helper')
require 'workflow'
class InheritanceTest < ActiveRecordTestCase

  test '#69 inheritance' do
    class Animal
      include Workflow

      workflow do

        state :conceived do
          event :birth, :transition_to => :born
        end

        state :born do

        end
      end
    end

    class Cat < Animal
      include Workflow
      workflow do

        state :upset do
          event :scratch, :transition_to => :hiding
        end

        state :hiding do

        end
      end
    end

    assert_equal [:born, :conceived] , sort_sym_array(Animal.workflow_spec.states.keys)
    assert_equal [:hiding, :upset], sort_sym_array(Cat.workflow_spec.states.keys), "Workflow definitions are not inherited"

    animal = Animal.new
    cat = Cat.new

    animal.birth!

    assert_raise NoMethodError, 'Methods defined by the old workflow spec should have be gone away' do
      cat.birth!
    end

    assert_equal [:birth!, :halt!, :process_event!], bang_methods(animal)
    assert_equal [:halt!, :process_event!, :scratch!], bang_methods(cat)
  end

  def sort_sym_array(a)
    a.sort { |a, b| a.to_s <=> b.to_s } # workaround for Ruby 1.8.7
  end

  def bang_methods(obj)
    non_trivial_methods = obj.public_methods-Object.public_methods
    methods_with_bang = non_trivial_methods.select {|m| m =~ /!$/}
    sort_sym_array(methods_with_bang).map {|m| m.to_sym}
  end
end
