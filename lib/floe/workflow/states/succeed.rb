# frozen_string_literal: true

module Floe
  class Workflow
    module States
      class Succeed < Floe::Workflow::State
        attr_reader :input_path, :output_path

        def initialize(workflow, name, payload)
          super

          @input_path  = Path.new(payload.fetch("InputPath", "$"))
          @output_path = Path.new(payload.fetch("OutputPath", "$"))
        end

        def end?
          true # TODO: Handle if this is ending a parallel or map state
        end

        private

        def execute!(input)
          input = input_path.value(context, input)
          output_path&.value(context, input)
        end
      end
    end
  end
end
