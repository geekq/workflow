module Workflow
  module Callbacks

    extend ActiveSupport::Concern
    include ActiveSupport::Callbacks

    CALLBACK_MAP =   {
      transition: :event,
      exit: :from,
      enter: :to
    }.freeze

    # @!attribute [r] transition_context
    #   During state transition events, contains a {TransitionContext} representing the transition underway.
    #   @return [TransitionContext] representation of current state transition
    #
    included do
      attr_reader :transition_context
      CALLBACK_MAP.keys.each do |type|
        define_callbacks type,
          skip_after_callbacks_if_terminated: true
      end
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
        CALLBACK_MAP.each do |type, context_attribute|
          define_method "#{callback}_#{type}" do |*names, &blk|
            _insert_callbacks(names, context_attribute, blk) do |name, options|
              set_callback(type, callback, name, options)
            end
          end

          define_method "prepend_#{callback}_#{type}" do |*names, &blk|
            _insert_callbacks(names, context_attribute, blk) do |name, options|
              set_callback(type, callback, name, options.merge(prepend: true))
            end
          end

          # Skip a before, after or around callback. See _insert_callbacks
          # for details on the allowed parameters.
          define_method "skip_#{callback}_#{type}" do |*names|
            _insert_callbacks(names, context_attribute) do |name, options|
              skip_callback(type, callback, name, options)
            end
          end

          # *_action is the same as append_*_action
          alias_method :"append_#{callback}_#{type}", :"#{callback}_#{type}"
        end
      end

      private
      def _insert_callbacks(callbacks, context_attribute, block = nil)
        options = callbacks.extract_options!
        _normalize_callback_options(options, context_attribute)
        callbacks.push(block) if block
        callbacks.each do |callback|
          yield callback, options
        end
      end

      def _normalize_callback_options(options, context_attribute)
        _normalize_callback_option(options, context_attribute, :only, :if)
        _normalize_callback_option(options, context_attribute, :except, :unless)
      end

      def _normalize_callback_option(options, context_attribute, from, to) # :nodoc:
        if from = options[from]
          _from = Array(from).map(&:to_sym).to_set
          from = proc { |record|
            _from.include? record.transition_context.send(context_attribute).to_sym
          }
          options[to] = Array(options[to]).unshift(from)
        end
      end
    end

    private
    #  TODO: Do something here.
    def halted_callback_hook(filter)
    end

    def run_all_callbacks(&block)
      catch(:abort) do
        run_callbacks :transition do
          throw(:abort) if false == run_callbacks(:exit) do
            throw(:abort) if false == run_callbacks(:enter, &block)
          end
        end
      end
    end
  end
end
