# frozen_string_literal: true

module Floe
  class Workflow
    module States
      class Choice < Floe::Workflow::State
        attr_reader :choices, :default, :input_path, :output_path

        def initialize(workflow, name, payload)
          super

          validate_state!(workflow)

          @choices = payload["Choices"].map.with_index { |choice, i| ChoiceRule.build(workflow, name + ["Choices", i.to_s], choice) }
          @default = payload["Default"]

          @input_path  = Path.new(payload.fetch("InputPath", "$"))
          @output_path = Path.new(payload.fetch("OutputPath", "$"))
        end

        def finish(context)
          input      = input_path.value(context, context.input)
          output     = output_path.value(context, input)
          next_state = choices.detect { |choice| choice.true?(context, output) }&.next || default

          runtime_field_error!("Default", nil, "not defined and no match found", :floe_error => "States.NoChoiceMatched") if next_state.nil?
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
          missing_field_error!("Choices") unless payload.key?("Choices")
          invalid_field_error!("Choices", nil, "must be a non-empty array") unless payload["Choices"].kind_of?(Array) && !payload["Choices"].empty?
        end

        def validate_state_default!(workflow)
          invalid_field_error!("Default", payload["Default"], "is not found in \"States\"") if payload["Default"] && !workflow_state?(payload["Default"], workflow)
        end
      end
    end
  end
end
