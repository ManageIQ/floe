# frozen_string_literal: true

module Floe
  class Workflow
    module States
      class Choice < Floe::Workflow::State
        fields do
          list("Choices", :required => true) { |wf, choice_name, choice_payload| ChoiceRule.build(wf, choice_name, choice_payload) }
          state_ref "Default"
          path "InputPath", :default => "$"
          path "OutputPath", :default => "$"
        end

        def initialize(workflow, full_name, payload)
          super

          load_fields(payload, workflow)
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
