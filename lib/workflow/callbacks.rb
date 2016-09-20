module Workflow
  module Callbacks

    extend ActiveSupport::Concern
    include ActiveSupport::Callbacks

    # @!attribute [r] transition_context
    #   During state transition events, contains a {TransitionContext} representing the transition underway.
    #   @return [TransitionContext] representation of current state transition
    #
    included do
      attr_reader :transition_context
      define_callbacks :transition,
        skip_after_callbacks_if_terminated: true
    end



    module ClassMethods
      ##
      # @!method before_transition
      #
      # :call-seq:
      #   before_transition(*instance_method_names, options={})
      #   before_transition(options={}, &block)
      #
      # Append a callback before transition.
      # Instance methods used for `before` and `after` transitions
      # receive no parameters.  Instance methods for `around` transitions will be given a block,
      # which must be yielded/called in order for the sequence to continue.
      #
      # Using a block notation, the first parameter will be an instance of the object
      # under transition, while the second parameter (`around` transition only) will be
      # the block which should be called for the sequence to continue.
      #
      # == Transition Metadata
      #
      # Within the callback you can access the `transition_context` instance variable,
      # which will give you metadata and arguments passed to the transition.
      # See Workflow::TransitionContext
      #
      # == Options
      #
      # === If / Unless
      #
      # The callback will run `if` or `unless` the named method returns a truthy value.
      #
      #    #  Assuming some_instance_method returns a boolean,
      #    before_transition :do_something, if: :some_instance_method
      #    before_transition :do_something_else, unless: :some_instance_method
      #
      # === Only / Except
      #
      # The callback will run `if` or `unless` the event being processed is in the list given
      #
      #     #  Run this callback only on the `accept` and `publish` events.
      #     before_transition :do_something, only: [:accept, :publish]
      #     #  Run this callback on events other than the `accept` and `publish` events.
      #     before_transition :do_something_else, except: [:accept, :publish]
      #

      ##
      # @!method prepend_before_transition(*instance_method_names, options={})
      #
      # Something Interesting
      #
      # @overload prepend_before_transition(options={}, &block)
      #
      # Prepend a callback before transition, making it the first before transition called.
      # Options are the same as for the standard #before_transition method.

      ##
      # @!method skip_before_transition
      #
      # :call-seq: skip_before_transition(names)
      #
      # Skip a callback before transition.
      # Options are the same as for the standard #before_transition method.

      ##
      # @!method after_transition
      #
      # :call-seq:
      #   after_transition(*instance_method_names, options={})
      #   after_transition(options={}, &block)
      #
      # Append a callback after transition.
      # Instance methods used for `before` and `after` transitions
      # receive no parameters.  Instance methods for `around` transitions will be given a block,
      # which must be yielded/called in order for the sequence to continue.
      #
      # Using a block notation, the first parameter will be an instance of the object
      # under transition, while the second parameter (`around` transition only) will be
      # the block which should be called for the sequence to continue.
      #
      # == Transition Metadata
      #
      # Within the callback you can access the `transition_context` instance variable,
      # which will give you metadata and arguments passed to the transition.
      # See Workflow::TransitionContext
      #
      # == Options
      #
      # === If / Unless
      #
      # The callback will run `if` or `unless` the named method returns a truthy value.
      #
      #    #  Assuming some_instance_method returns a boolean,
      #    after_transition :do_something, if: :some_instance_method
      #    after_transition :do_something_else, unless: :some_instance_method
      #
      # === Only / Except
      #
      # The callback will run `if` or `unless` the event being processed is in the list given
      #
      #     #  Run this callback only on the `accept` and `publish` events.
      #     after_transition :do_something, only: [:accept, :publish]
      #     #  Run this callback on events other than the `accept` and `publish` events.
      #     after_transition :do_something_else, except: [:accept, :publish]
      #

      ##
      # @!method prepend_after_transition(*instance_method_names, options={})
      #
      # Something Interesting
      #
      # @overload prepend_after_transition(options={}, &block)
      #
      # Prepend a callback after transition, making it the first after transition called.
      # Options are the same as for the standard #after_transition method.

      ##
      # @!method skip_after_transition
      #
      # :call-seq: skip_after_transition(names)
      #
      # Skip a callback after transition.
      # Options are the same as for the standard #after_transition method.

      ##
      # @!method around_transition
      #
      # :call-seq:
      #   around_transition(*instance_method_names, options={})
      #   around_transition(options={}, &block)
      #
      # Append a callback around transition.
      # Instance methods used for `before` and `after` transitions
      # receive no parameters.  Instance methods for `around` transitions will be given a block,
      # which must be yielded/called in order for the sequence to continue.
      #
      # Using a block notation, the first parameter will be an instance of the object
      # under transition, while the second parameter (`around` transition only) will be
      # the block which should be called for the sequence to continue.
      #
      # == Transition Metadata
      #
      # Within the callback you can access the `transition_context` instance variable,
      # which will give you metadata and arguments passed to the transition.
      # See Workflow::TransitionContext
      #
      # == Options
      #
      # === If / Unless
      #
      # The callback will run `if` or `unless` the named method returns a truthy value.
      #
      #    #  Assuming some_instance_method returns a boolean,
      #    around_transition :do_something, if: :some_instance_method
      #    around_transition :do_something_else, unless: :some_instance_method
      #
      # === Only / Except
      #
      # The callback will run `if` or `unless` the event being processed is in the list given
      #
      #     #  Run this callback only on the `accept` and `publish` events.
      #     around_transition :do_something, only: [:accept, :publish]
      #     #  Run this callback on events other than the `accept` and `publish` events.
      #     around_transition :do_something_else, except: [:accept, :publish]
      #

      ##
      # @!method prepend_around_transition(*instance_method_names, options={})
      #
      # Something Interesting
      #
      # @overload prepend_around_transition(options={}, &block)
      #
      # Prepend a callback around transition, making it the first around transition called.
      # Options are the same as for the standard #around_transition method.

      ##
      # @!method skip_around_transition
      #
      # :call-seq: skip_around_transition(names)
      #
      # Skip a callback around transition.
      # Options are the same as for the standard #around_transition method.

      [:before, :after, :around].each do |callback|
        define_method "#{callback}_transition" do |*names, &blk|
          _insert_callbacks(names, blk) do |name, options|
            set_callback(:transition, callback, name, options)
          end
        end

        define_method "prepend_#{callback}_transition" do |*names, &blk|
          _insert_callbacks(names, blk) do |name, options|
            set_callback(:transition, callback, name, options.merge(prepend: true))
          end
        end

        # Skip a before, after or around callback. See _insert_callbacks
        # for details on the allowed parameters.
        define_method "skip_#{callback}_transition" do |*names|
          _insert_callbacks(names) do |name, options|
            skip_callback(:transition, callback, name, options)
          end
        end

        # *_action is the same as append_*_action
        alias_method :"append_#{callback}_transition", :"#{callback}_transition"
      end

      private
      def _insert_callbacks(callbacks, block = nil)
        options = callbacks.extract_options!
        _normalize_callback_options(options)
        callbacks.push(block) if block
        callbacks.each do |callback|
          yield callback, options
        end
      end

      def _normalize_callback_options(options)
        _normalize_callback_option(options, :only, :if)
        _normalize_callback_option(options, :except, :unless)
      end

      def _normalize_callback_option(options, from, to) # :nodoc:
        if from = options[from]
          _from = Array(from).map(&:to_s).to_set
          from = proc { |record|
            _from.include? record.transition_context.event.to_s
          }
          options[to] = Array(options[to]).unshift(from)
        end
      end
    end

    private
    def execute_transition!(from, to, event_name, event, *args)
      # byebug
      @transition_context = TransitionContext.new \
        from: from.name,
        to: to.name,
        event: event_name,
        event_args: args,
        named_arguments: workflow_spec.named_arguments

      run_callbacks :transition do
        return_value = false
        catch(:abort) do
          # byebug
          callback_value   = run_action_callback event_name, *args
          return_value   = callback_value
          return_value ||= persist_workflow_state(to.name)
        end
        return_value
      end
    end
  end
end
