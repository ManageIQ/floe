# frozen_string_literal: true

module Floe
  class Workflow
    module States
      class Choice < Floe::Workflow::State
        attr_reader :choices, :default, :input_path, :output_path

        def initialize(workflow, full_name, payload)
          super

          validate_state!(workflow)
          @choices = payload["Choices"].each_with_index.map { |choice, i| ChoiceRule.build(full_name + ["Choices", i.to_s], choice) }
          @default = payload["Default"]

          @input_path  = path!("InputPath", payload.fetch("InputPath", "$"))
          @output_path = path!("OutputPath", payload.fetch("OutputPath", "$"))
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
          require_fields!("Choices" => payload["Choices"])
        end

        def validate_state_default!(workflow)
          state_ref!("Default", payload["Default"], workflow)
        end
      end
    end
  end
end
