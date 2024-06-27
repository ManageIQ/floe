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

          @next        = state_ref!("Next", payload["Next"], workflow)
          @end         = !!payload["End"]
          @result      = payload["Result"]

          @parameters  = payload_template!("Parameters", payload["Parameters"])
          @input_path  = path!("InputPath", payload.fetch("InputPath", "$"))
          @output_path = path!("OutputPath", payload.fetch("OutputPath", "$"))
          @result_path = reference_path!("ResultPath", payload.fetch("ResultPath", "$"))

          validate_state!
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

        def validate_state!
          require_field!("Next", @next) unless @end
        end
      end
    end
  end
end
