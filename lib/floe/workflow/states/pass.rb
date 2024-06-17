# frozen_string_literal: true

module Floe
  class Workflow
    module States
      class Pass < Floe::Workflow::State
        include InputOutputMixin
        include NonTerminalMixin

        attr_reader :result

        def initialize(workflow, name, payload)
          super

          @result = payload["Result"]
        end

        def finish(context)
          input = result.nil? ? process_input(context) : result
          context.output = process_output(context, input)
          super
        end

        def running?(_)
          false
        end
      end
    end
  end
end
