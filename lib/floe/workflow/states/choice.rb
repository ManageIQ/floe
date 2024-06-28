# frozen_string_literal: true

module Floe
  class Workflow
    module States
      class Choice < Floe::Workflow::State
        attr_reader :choices, :default, :input_path, :output_path

        def initialize(workflow, full_name, payload)
          super

          validate_state!(workflow)

          @choices = payload["Choices"].map.with_index { |choice, i| ChoiceRule.build(full_name + ["Choices", i.to_s], choice) }
          @default = payload["Default"]

          @input_path  = Path.new(payload.fetch("InputPath", "$"))
          @output_path = Path.new(payload.fetch("OutputPath", "$"))
        end

        def finish(context)
          input      = input_path.value(context, context.input)
          output     = output_path.value(context, input)
          next_state = choices.detect { |choice| choice.true?(context, output) }&.next || default

          context.next_state = next_state
          context.output     = output
          super
        end

        def running?(_)
          false
        end

        def end?
          false
        end

        private

        def validate_state!(workflow)
          validate_state_choices!
          validate_state_default!(workflow)
        end

        def validate_state_choices!
          raise Floe::InvalidWorkflowError, "Choice state must have \"Choices\"" unless payload.key?("Choices")
          raise Floe::InvalidWorkflowError, "\"Choices\" must be a non-empty array" unless payload["Choices"].kind_of?(Array) && !payload["Choices"].empty?
        end

        def validate_state_default!(workflow)
          raise Floe::InvalidWorkflowError, "\"Default\" not in \"States\"" unless workflow.payload["States"].include?(payload["Default"])
        end
      end
    end
  end
end
