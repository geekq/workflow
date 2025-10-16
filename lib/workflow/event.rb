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

    def condition_applicable?(object, event_arguments)
      if condition
        if condition.is_a?(Symbol)
          m = object.method(condition)
          # Conditionals can now take the arguments of the trasition action into account #227
          # But in case the current conditional wants to ignore any event_argument on its decision -
          # does not accept parameters, also support that.
          if m.arity == 0 # no additional parameters accepted
            object.send(condition)
          else
            object.send(condition, *event_arguments)
          end
        else
          # since blocks can ignore extra arguments without raising an error in Ruby,
          # no `if` is needed - compare with `arity` switch in above methods handling
          condition.call(object, *event_arguments)
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
  end
end
