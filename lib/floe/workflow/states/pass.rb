# frozen_string_literal: true

module Floe
  class Workflow
    module States
      class Pass < Floe::Workflow::State
        attr_reader :result, :parameters, :input_path, :output_path, :result_path

        def initialize(workflow, name, payload)
          super

          @result      = payload["Result"]

          @parameters  = PayloadTemplate.new(payload["Parameters"]) if payload["Parameters"]
          @input_path  = Path.new(payload.fetch("InputPath", "$"))
          @output_path = Path.new(payload.fetch("OutputPath", "$"))
          @result_path = ReferencePath.new(payload.fetch("ResultPath", "$"))
        end

        def run_input!(input)
          output = input_path.value(context, input)
          output = result_path.set(output, result) if result && result_path
          output_path.value(context, output)
        end
      end
    end
  end
end
