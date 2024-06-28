# frozen_string_literal: true

module Floe
  class Workflow
    module States
      class Fail < Floe::Workflow::State
        fields do
          string "Cause"
          string "Error"
          path "CausePath"
          path "ErrorPath"

          require_set "Error", "ErrorPath"
        end

        def initialize(workflow, name, payload)
          super

          load_fields(payload, workflow)
        end

        def finish(context)
          context.next_state = nil
          # TODO: support intrinsic functions here
          # see https://docs.aws.amazon.com/step-functions/latest/dg/amazon-states-language-fail-state.html
          #     https://docs.aws.amazon.com/step-functions/latest/dg/amazon-states-language-intrinsic-functions.html#asl-intrsc-func-generic
          context.output     = {
            "Error" => @error_path ? @error_path.value(context, context.input) : error,
            "Cause" => @cause_path ? @cause_path.value(context, context.input) : cause
          }.compact
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
