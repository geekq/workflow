module Workflow
  class State

    attr_accessor :name, :events, :meta, :on_entry, :on_exit
    attr_reader :spec

    def initialize(name, spec, meta = {})
      @name, @spec, @events, @meta = name, spec, Hash.new, meta
    end

    def draw(graph, options={})
      node = graph.add_node(to_s,
        :label => to_s,
        :width => '1',
        :height => '1',
        :shape => 'ellipse'
      )

      # Add open arrow for initial state
      # graph.add_edge(graph.add_node('starting_state', :shape => 'point'), node) if initial?

      node
    end

    unless RUBY_VERSION < '1.9'
      include Comparable

      def <=>(other_state)
        states = spec.states.keys
        raise ArgumentError, "state `#{other_state}' does not exist" unless other_state.in? states
        if states.index(self.to_sym) < states.index(other_state.to_sym)
          -1
        elsif states.index(self.to_sym) > states.index(other_state.to_sym)
          1
        else
          0
        end
      end
    end

    def to_s
      "#{name}"
    end

    def to_sym
      name.to_sym
    end
  end
end