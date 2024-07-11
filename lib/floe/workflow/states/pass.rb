# frozen_string_literal: true

module Floe
  class Workflow
    module States
      class Pass < Floe::Workflow::State
        include InputOutputMixin
        include NonTerminalMixin

        attr_reader :end, :next, :result, :parameters, :input_path, :output_path, :result_path

        def initialize(workflow, name, payload)
          super

          @next        = payload["Next"]
          @end         = !!payload["End"]
          @result      = payload["Result"]

          @parameters  = wrap_parser_error("Parameters", payload["Parameters"]) { PayloadTemplate.new(payload["Parameters"]) } if payload["Parameters"]
          @input_path  = wrap_parser_error("InputPath", payload.fetch("InputPath", nil)) { Path.new(payload.fetch("InputPath", "$")) }
          @output_path = wrap_parser_error("OutputPath", payload.fetch("OutputPath", nil)) { Path.new(payload.fetch("OutputPath", "$")) }
          @result_path = wrap_parser_error("ResultPath", payload.fetch("ResultPath", nil)) { ReferencePath.new(payload.fetch("ResultPath", "$")) }

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
