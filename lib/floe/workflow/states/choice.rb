# frozen_string_literal: true

module Floe
  class Workflow
    module States
      class Choice < Floe::Workflow::State
        attr_reader :choices, :default, :input_path, :output_path

        def initialize(name, payload, _credentials = nil)
          super

          @choices = payload["Choices"].map { |choice| ChoiceRule.build(choice) }
          @default = payload["Default"]

          @input_path  = Path.new(payload.fetch("InputPath", "$"))
          @output_path = Path.new(payload.fetch("OutputPath", "$"))
        end

        def run!(context)
          input      = input_path.value(context, context.input)
          # NOTE: context.input != input
          next_state = choices.detect { |choice| choice.true?(context, input) }&.next || default
          output     = output_path.value(context, input)

          context.end_state!(output, next_state)
        end

        def end?
          false
        end
      end
    end
  end
end
