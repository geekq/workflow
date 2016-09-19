module Workflow
  module Adapter
    module BasicCallbacks
      private

      def execute_transition!(from, to, name, event, *args)
        run_around_transition(from, to, name, *args) do
          run_before_transition(from, to, name, *args)
          return false if @halted

          begin
            return_value = run_action(event.action, *args) || run_action_callback(name, *args)
          rescue StandardError => e
            run_on_error(e, from, to, name, *args)
          end

          return false if @halted

          run_on_transition(from, to, name, *args)

          run_on_exit(from, to, name, *args)

          transition_value = persist_workflow_state to.to_s

          run_on_entry(to, from, name, *args)

          run_after_transition(from, to, name, *args)

          return_value.nil? ? transition_value : return_value
        end
      end

      def run_before_transition(from, to, event, *args)
        instance_exec(from.name, to.name, event, *args, &spec.before_transition_proc) if
          spec.before_transition_proc
      end

      def run_on_error(error, from, to, event, *args)
        if spec.on_error_proc
          instance_exec(error, from.name, to.name, event, *args, &spec.on_error_proc)
          halt(error.message)
        else
          raise error
        end
      end

      def run_on_transition(from, to, event, *args)
        instance_exec(from.name, to.name, event, *args, &spec.on_transition_proc) if spec.on_transition_proc
      end

      def run_around_transition(from, to, event, *args, &transition)
        if spec.around_transition_proc
          instance_exec(from.name, to.name, event, transition, *args, &spec.around_transition_proc)
        else
          yield
        end
      end

      def run_after_transition(from, to, event, *args)
        instance_exec(from.name, to.name, event, *args, &spec.after_transition_proc) if
          spec.after_transition_proc
      end

      def run_action(action, *args)
        instance_exec(*args, &action) if action
      end

      def run_on_entry(state, prior_state, triggering_event, *args)
        if state.on_entry
          instance_exec(prior_state.name, triggering_event, *args, &state.on_entry)
        else
          hook_name = "on_#{state}_entry"
          self.send hook_name, prior_state, triggering_event, *args if has_callback?(hook_name)
        end
      end

      def run_on_exit(state, new_state, triggering_event, *args)
        if state
          if state.on_exit
            instance_exec(new_state.name, triggering_event, *args, &state.on_exit)
          else
            hook_name = "on_#{state}_exit"
            self.send hook_name, new_state, triggering_event, *args if has_callback?(hook_name)
          end
        end
      end
    end
  end
end
