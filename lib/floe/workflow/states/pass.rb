# frozen_string_literal: true

module Floe
  class Workflow
    module States
      class Pass < Floe::Workflow::State
        include InputOutputMixin
        include NonTerminalMixin

        attr_reader :end, :next, :result, :parameters, :input_path, :output_path, :result_path

        def initialize(validator, name, payload)
          super

          @end         = !!payload["End"]
          @next        = validator.validate_state_ref!("Next", payload["Next"], :optional => @end)
          @result      = payload["Result"]

          @parameters  = PayloadTemplate.new(payload["Parameters"]) if payload["Parameters"]
          @input_path  = Path.new(payload.fetch("InputPath", "$"))
          @output_path = Path.new(payload.fetch("OutputPath", "$"))
          @result_path = ReferencePath.new(payload.fetch("ResultPath", "$"))
        end

        def finish(context)
          context.output = process_output(context, result)
          super
        end

        def running?(_)
          false
        end

        def end?
          @end
        end
      end
    end
  end
end
