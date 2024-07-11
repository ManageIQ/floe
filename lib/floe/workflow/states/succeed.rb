# frozen_string_literal: true

module Floe
  class Workflow
    module States
      class Succeed < Floe::Workflow::State
        attr_reader :input_path, :output_path

        def initialize(workflow, name, payload)
          super

          @input_path  = wrap_parser_error("InputPath", payload.fetch("InputPath", nil)) { Path.new(payload.fetch("InputPath", "$")) }
          @output_path = wrap_parser_error("OutputPath", payload.fetch("OutputPath", nil)) { Path.new(payload.fetch("OutputPath", "$")) }
        end

        def finish(context)
          input              = input_path.value(context, context.input)
          context.output     = output_path.value(context, input)
          context.next_state = nil

          super
        end

        def running?(_)
          false
        end

        def end?
          true
        end
      end
    end
  end
end
