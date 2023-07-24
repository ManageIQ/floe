# frozen_string_literal: true

module Floe
  class Workflow
    module States
      class Pass < Floe::Workflow::State
        attr_reader :result, :parameters, :result_path

        def initialize(workflow, name, payload)
          super

          @result      = payload["Result"]

          @parameters  = PayloadTemplate.new(payload["Parameters"]) if payload["Parameters"]
          @result_path = ReferencePath.new(payload.fetch("ResultPath", "$"))
        end

        def run_input!(input)
          result && result_path ? result_path.set(input, result) : input
        end
      end
    end
  end
end
