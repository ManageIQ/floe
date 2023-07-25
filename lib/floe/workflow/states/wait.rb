# frozen_string_literal: true

module Floe
  class Workflow
    module States
      class Wait < Floe::Workflow::State
        attr_reader :seconds, :input_path, :output_path

        def initialize(workflow, name, payload)
          super

          @seconds = payload["Seconds"].to_i

          @input_path  = Path.new(payload.fetch("InputPath", "$"))
          @output_path = Path.new(payload.fetch("OutputPath", "$"))
        end

        def run_input!(input)
          input = input_path.value(context, input)
          sleep(seconds)
          output_path.value(context, input)
        end
      end
    end
  end
end
