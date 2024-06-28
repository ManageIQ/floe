# frozen_string_literal: true

module Floe
  class Workflow
    module States
      module NonTerminalMixin
        def finish(context)
          # If this state is failed or this is an end state, next_state to nil
          context.next_state ||= end? || context.failed? ? nil : @next

          super
        end

        def validate_state_next!(workflow)
          parser_missing_field!("Next") if @next.nil? && !@end
          parser_invalid_field!("Next", @next, "is not found in \"States\"") if @next && !workflow_state?(@next, workflow)
        end
      end
    end
  end
end
