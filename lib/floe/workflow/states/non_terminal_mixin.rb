# frozen_string_literal: true

module Floe
  class Workflow
    module States
      module NonTerminalMixin
        def finish
          # If this state is failed or this is an end state, next_state to nil
          context.next_state ||= end? || context.failed? ? nil : @next

          super
        end

        def validate_state_next!
          workflow.validator.for_state(name).validate_state_ref!("Next", @next, :optional => @end)
        end
      end
    end
  end
end
