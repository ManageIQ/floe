# frozen_string_literal: true

module Floe
  class Workflow
    module States
      class Fail < Floe::Workflow::State
        attr_reader :cause, :error

        def initialize(workflow, name, payload)
          super

          @cause      = payload["Cause"]
          @error      = payload["Error"]
          @cause_path = payload.path!("CausePath", :default => nil)
          @error_path = payload.path!("ErrorPath", :default => nil)
        end

        def finish
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

        def running?
          false
        end

        def end?
          true
        end
      end
    end
  end
end
