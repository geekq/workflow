module Workflow
  class Event
    attr_reader :name, :transitions, :meta

    def initialize(name, meta)
      @name = name.to_sym
      @transitions = []
      @meta = meta || {}
    end

    def inspect
      "<Event name=#{name.inspect} transitions(#{transitions.length})=#{transitions.inspect}>"
    end

    def evaluate(target)
      transition = transitions.find{|t| t.apply? target}
      if transition
        return transition.target_state
      else
        nil
      end
    end

    def to(target_state, **conditions_def, &block)
      conditions = Conditions.new &&conditions_def, block
      self.transitions << Transition.new(target_state, conditions_def, &block)
    end

    private
    class Transition
      attr_accessor :target_state, :conditions
      def apply?(target)
        conditions.apply?(target)
      end
      # delegate :apply?, to: :conditions
      def initialize(target_state, conditions_def, &block)
        @target_state = target_state
        @conditions = Conditions.new conditions_def, &block
      end

      def inspect
        "<to=#{target_state.inspect} conditions=#{conditions.inspect}"
      end
    end

    class Conditions #:nodoc:#

      def initialize(**options, &block)
        @if      = Array(options[:if])
        @unless  = Array(options[:unless])
        @if      << block if block_given?
        @conditions_lambdas = conditions_lambdas
      end

      def inspect
        "if: #{@if}, unless: #{@unless}"
      end

      def apply?(target)
        # TODO: Remove the second parameter from the conditions below.
        @conditions_lambdas.all?{|l| l.call(target, ->(){})}
      end

      private

      # Copied from https://github.com/rails/rails/blob/bca2e69b785fa3cdbe148b0d2dd5d3b58f6daf53/activesupport/lib/active_support/callbacks.rb#L366
      def invert_lambda(l)
        lambda { |*args, &blk| !l.call(*args, &blk) }
      end

      # Filters support:
      #
      #   Symbols:: A method to call.
      #   Strings:: Some content to evaluate.
      #   Procs::   A proc to call with the object.
      #   Objects:: An object with a <tt>before_foo</tt> method on it to call.
      #
      # All of these objects are converted into a lambda and handled
      # the same after this point.
      # Copied from https://github.com/rails/rails/blob/bca2e69b785fa3cdbe148b0d2dd5d3b58f6daf53/activesupport/lib/active_support/callbacks.rb#L379
      def make_lambda(filter)
        case filter
        when Symbol
          lambda { |target, _, &blk| target.send filter, &blk }
        when String
          l = eval "lambda { |value| #{filter} }"
        lambda { |target, value| target.instance_exec(value, &l) }
        # when Conditionals::Value then filter
        when ::Proc
          if filter.arity > 1
            return lambda { |target, _, &block|
              raise ArgumentError unless block
              target.instance_exec(target, block, &filter)
            }
          end

          if filter.arity <= 0
            lambda { |target, _| target.instance_exec(&filter) }
          else
            lambda { |target, _| target.instance_exec(target, &filter) }
          end
        else
          scopes = Array(chain_config[:scope])
          method_to_call = scopes.map{ |s| public_send(s) }.join("_")

          lambda { |target, _, &blk|
            filter.public_send method_to_call, target, &blk
          }
        end
      end

      # From https://github.com/rails/rails/blob/bca2e69b785fa3cdbe148b0d2dd5d3b58f6daf53/activesupport/lib/active_support/callbacks.rb#L410
      def compute_identifier(filter)
        case filter
        when String, ::Proc
          filter.object_id
        else
          filter
        end
      end

      # From https://github.com/rails/rails/blob/bca2e69b785fa3cdbe148b0d2dd5d3b58f6daf53/activesupport/lib/active_support/callbacks.rb#L419
      def conditions_lambdas
        @if.map { |c| make_lambda c } +
          @unless.map { |c| invert_lambda make_lambda c }
      end
    end
  end
end
