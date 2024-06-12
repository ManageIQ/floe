# frozen_string_literal: true

module Floe
  class Workflow
    module States
      class Choice < Floe::Workflow::State
        attr_reader :choices, :default, :input_path, :output_path

        def initialize(workflow, name, payload)
          super

          validator = workflow.validator.for_state(name)

          validator.validate_list!("Choices", payload["Choices"])

          @choices = payload["Choices"].map { |choice| ChoiceRule.build(choice) }
          @default = validator.validate_state_ref!("Default", payload["Default"])

          @input_path  = Path.new(payload.fetch("InputPath", "$"))
          @output_path = Path.new(payload.fetch("OutputPath", "$"))
        end

        def finish
          output     = output_path.value(context, context.input)
          next_state = choices.detect { |choice| choice.true?(context, output) }&.next || default

          context.next_state = next_state
          context.output     = output
          super
        end

        def running?
          false
        end

        def end?
          false
        end
      end
    end
  end
end
