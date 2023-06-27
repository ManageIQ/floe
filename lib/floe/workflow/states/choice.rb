# frozen_string_literal: true

module Floe
  class Workflow
    module States
      class Choice < Floe::Workflow::State
        attr_reader :choices, :default, :input_path, :output_path

        def initialize(workflow, name, payload)
          super

          @choices = payload["Choices"].map { |choice| ChoiceRule.build(choice) }
          @default = payload["Default"]

          @input_path  = Path.new(payload.fetch("InputPath", "$"))
          @output_path = Path.new(payload.fetch("OutputPath", "$"))
        end

        def execute!(input)
          @next = choices.detect { |choice| choice.true?(context, input) }&.next || default
          input
        end
      end
    end
  end
end
