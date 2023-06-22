# frozen_string_literal: true

module Floe
  class Workflow
    module States
      class Pass < Floe::Workflow::State
        attr_reader :end, :next, :result, :parameters, :input_path, :output_path, :result_path

        def initialize(workflow, name, payload)
          super

          @next        = payload["Next"]
          @result      = payload["Result"]

          @parameters  = PayloadTemplate.new(payload["Parameters"]) if payload["Parameters"]
          @input_path  = Path.new(payload.fetch("InputPath", "$"))
          @output_path = Path.new(payload.fetch("OutputPath", "$"))
          @result_path = ReferencePath.new(payload.fetch("ResultPath", "$"))
        end

        def run!(*)
          super do |input|
            result_path.set(input, result) if result && result_path
          end
        end
      end
    end
  end
end
