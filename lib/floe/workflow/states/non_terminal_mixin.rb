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
      end
    end
  end
end
