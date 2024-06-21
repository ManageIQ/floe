# frozen_string_literal: true

module Floe
  class Workflow
    module States
      class Choice < Floe::Workflow::State
        attr_reader :choices, :default, :input_path, :output_path

        def initialize(workflow, name, payload)
          super

          @choices = payload.list!("Choices").map { |choice_payload| ChoiceRule.build(payload.for_rule("Choices", choice_payload)) }
          @default = payload.state_ref!("Default", :required => false)

          @input_path  = payload.path!("InputPath", :default => "$")
          @output_path = payload.path!("OutputPath", :default => "$")

          payload.no_unreferenced_fields!
        end

        def finish(context)
          output     = output_path.value(context, context.input)
          next_state = choices.detect { |choice| choice.true?(context, output) }&.next || default

          context.next_state = next_state
          context.output     = next_state ? output : {"Error" => "States.NoChoiceMatched", "Cause" => "No match found"}

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
