# frozen_string_literal: true

module Floe
  class Workflow
    module States
      class Choice < Floe::Workflow::State
        attr_reader :choices, :default, :input_path, :output_path

        def initialize(workflow, full_name, payload)
          super

          @choices     = list!("Choices", payload["Choices"], workflow) { |wf, choice_name, choice_payload| ChoiceRule.build(wf, choice_name, choice_payload) }
          @default     = state_ref!("Default", payload["Default"], workflow)

          @input_path  = path!("InputPath", payload.fetch("InputPath", "$"))
          @output_path = path!("OutputPath", payload.fetch("OutputPath", "$"))

          require_fields!("Choices" => payload["Choices"])
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
      end
    end
  end
end
