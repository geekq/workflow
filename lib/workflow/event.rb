module Workflow
  class Event

    attr_accessor :name, :transitions_to, :meta, :action

    def initialize(name, transitions_to, meta = {}, &action)
      @name, @transitions_to, @meta, @action = name, transitions_to.to_sym, meta, action
    end

    def draw(graph, from_state)
      graph.add_edges(from_state.name.to_s, transitions_to.to_s, meta.merge(:label => to_s))
    end

    def to_s
      @name.to_s
    end
  end
end