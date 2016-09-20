require 'active_support/concern'
require 'active_support/callbacks'

module Workflow
  module Adapter
    module ActiveSupportCallbacks
      extend ActiveSupport::Concern
      included do
        include ActiveSupport::Callbacks
        attr_reader :transition_context
        define_callbacks :transition,
          skip_after_callbacks_if_terminated: true
      end

      module ClassMethods
        ##
        # :method: before_transition
        #
        # :call-seq:
        #   before_transition(*instance_method_names, options={})
        #   before_transition(*instance_method_names)
        #   before_transition(*instance_method_names)
        #
        # Append a callback before transitions. See _insert_callbacks for parameter details.

        ##
        # :method: prepend_before_transition
        #
        # :call-seq: prepend_before_transition(names, block)
        #
        # Prepend a callback before transitions. See _insert_callbacks for parameter details.

        ##
        # :method: skip_before_transition
        #
        # :call-seq: skip_before_transition(names)
        #
        # Skip a callback before transitions. See _insert_callbacks for parameter details.

        ##
        # :method: after_transition
        #
        # :call-seq: after_transition(names, block)
        #
        # Append a callback after transitions. See _insert_callbacks for parameter details.

        ##
        # :method: prepend_after_transition
        #
        # :call-seq: prepend_after_transition(names, block)
        #
        # Prepend a callback after transitions. See _insert_callbacks for parameter details.

        ##
        # :method: skip_after_transition
        #
        # :call-seq: skip_after_transition(names)
        #
        # Skip a callback after transitions. See _insert_callbacks for parameter details.

        ##
        # :method: around_transition
        #
        # :call-seq:
        #   around_transition(*instance_method_names, options)
        #   around_transition(options) {}
        #
        #
        # Append a callback around transitions. See _insert_callbacks for parameter details.

        ##
        # :method: prepend_around_transition
        #
        # :call-seq: prepend_around_transition(names, block)
        #
        # Prepend a callback around transitions. See _insert_callbacks for parameter details.

        ##
        # :method: skip_around_transition
        #
        # :call-seq: skip_around_transition(names)
        #
        # Skip a callback around transitions. See _insert_callbacks for parameter details.

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
        @transition_context = TransitionContext.new \
          from: from.name,
          to: to.name,
          event: event_name,
          event_args: args

        callback_value, transition_value = [nil, nil]
        run_callbacks :transition do
          callback_value   = run_action_callback event_name, *args
          transition_value = persist_workflow_state to.to_s
        end

        callback_value || transition_value
      end
    end
  end
end
