# frozen_string_literal: true

module Floe
  class Workflow
    module States
      class Pass < Floe::Workflow::State
        include InputOutputMixin
        include NonTerminalMixin

        attr_reader :end, :next, :result

        def initialize(workflow, name, payload)
          super

          @next        = payload["Next"]
          @end         = !!payload["End"]
          @result      = payload["Result"]

          validate_state!(workflow)
        end

        def finish(context)
          input = result.nil? ? process_input(context) : result
          context.output = process_output(context, input)
          super
        end

        def running?(_)
          false
        end

        def end?
          @end
        end

        private

        def validate_state!(workflow)
          validate_state_next!(workflow)
        end
      end
    end
  end
end
