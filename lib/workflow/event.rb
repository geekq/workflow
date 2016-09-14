module Workflow
  class Event

    attr_accessor :name, :transitions_to, :meta, :action, :condition

    def initialize(name, transitions_to, condition = nil, meta = {}, &action)
      @name = name
      @transitions_to = transitions_to.to_sym
      @meta = meta
      @action = action
      @condition = if condition.nil? || condition.is_a?(Symbol) || condition.respond_to?(:call)
                     condition
                   else
                     raise TypeError, 'condition must be nil, an instance method name symbol or a callable (eg. a proc or lambda)'
                   end
    end

    def condition_applicable?(object)
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

    def draw(graph, from_state)
      graph.add_edges(from_state.name.to_s, transitions_to.to_s, meta.merge(:label => to_s))
    end

    def to_s
      @name.to_s
    end

    def as_json(*)
      {
          name: name,
          transitions_to: transitions_to,
          meta: meta,
          action: action,
          condition: condition
      }
    end

    def from_json!(json_obj)
      @name = json_obj['name'].to_sym
      @transitions_to = json_obj['transitions_to'].to_sym
      @meta = json_obj['meta']
      @action = json_obj['action']

      # TODO: Pending condition object. Review action...
      #@condition = json_obj[:condition]
    end
  end
end
