module Workflow
  class Event

    attr_accessor :name, :transitions_to, :meta, :condition

    def initialize(name, transitions_to, condition = nil, meta = {})
      @name = name
      @transitions_to = transitions_to
      @meta = meta
      @condition = if condition.nil? || condition.is_a?(Symbol) || condition.respond_to?(:call)
                     condition
                   else
                     raise TypeError, 'condition must be nil, an instance method name symbol or a callable (eg. a proc or lambda)'
                   end
    end

    def conditions_apply?(object)
      if condition
        if condition.is_a?(Symbol)
          object.send(condition)
        else
          condition.call(object)
        end
      else
        true
      end
    end

    def to_s
      @name.to_s
    end
  end
end
