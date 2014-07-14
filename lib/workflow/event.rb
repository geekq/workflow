module Workflow
  class Event

    attr_accessor :name, :transitions_to, :meta, :action, :condition

    def initialize(name, transitions_to, condition = nil, meta = {}, &action)
      @name = name
      @transitions_to = transitions_to.to_sym
      @meta = meta
      @action = action
      @condition = if condition.nil? || condition.respond_to?(:call)
                     condition
                   else
                     raise TypeError, 'condition must be nil or callable (eg. a proc or lambda)'
                   end
    end

    def condition_applicable?(object)
      condition ? condition.call(object) : true
    end

    def draw(graph, from_state)
      graph.add_edges(from_state.name.to_s, transitions_to.to_s, meta.merge(:label => to_s))
    end

    def to_s
      @name.to_s
    end
  end
end
