# frozen_string_literal: true

module Floe
  class Workflow
    module States
      class Pass < Floe::Workflow::State
        attr_reader :end, :next, :result, :parameters, :input_path, :output_path, :result_path

        def initialize(name, payload, _credentials = nil)
          super

          @next        = payload["Next"]
          @end         = !!payload["End"]
          @result      = payload["Result"]

          @parameters  = PayloadTemplate.new(payload["Parameters"]) if payload["Parameters"]
          @input_path  = Path.new(payload.fetch("InputPath", "$"))
          @output_path = Path.new(payload.fetch("OutputPath", "$"))
          @result_path = ReferencePath.new(payload.fetch("ResultPath", "$"))
        end

        def run!(context)
          output = input_path.value(context, context.input)
          output = result_path.set(output, result) if result
          output = output_path.value(context, output)

          context.end_state!(output, @next)
        end

        def end?
          @end
        end
      end
    end
  end
end
