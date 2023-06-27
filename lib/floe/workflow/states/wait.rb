# frozen_string_literal: true

module Floe
  class Workflow
    module States
      class Wait < Floe::Workflow::State
        attr_reader :end, :next, :seconds, :input_path, :output_path

        def initialize(workflow, name, payload)
          super

          @next    = payload["Next"]
          @seconds = payload["Seconds"].to_i

          @input_path  = Path.new(payload.fetch("InputPath", "$"))
          @output_path = Path.new(payload.fetch("OutputPath", "$"))
        end

        def execute!(input)
          sleep(seconds)
          input
        end
      end
    end
  end
end
