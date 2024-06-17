# frozen_string_literal: true

module Floe
  class Workflow
    module States
      module NonTerminalMixin
        attr_reader :next, :end

        def initialize(workflow, name, payload)
          super

          @next        = payload["Next"]
          @end         = !!payload["End"]

          validate_state_next!(workflow)
        end

        def finish(context)
          # If this state is failed or this is an end state, next_state to nil
          context.next_state ||= end? || context.failed? ? nil : @next

          super
        end

        def end?
          @end
        end

        private

        def validate_state_next!(workflow)
          raise Floe::InvalidWorkflowError, "Missing \"Next\" field in state [#{name}]" if @next.nil? && !@end
          raise Floe::InvalidWorkflowError, "\"Next\" [#{@next}] not in \"States\" for state [#{name}]" if @next && !workflow.payload["States"].key?(@next)
        end
      end
    end
  end
end
