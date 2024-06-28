# frozen_string_literal: true

module Floe
  class Workflow
    module States
      class Pass < Floe::Workflow::State
        include InputOutputMixin
        include NonTerminalMixin

        fields do
          state_ref        "Next"
          boolean          "End"
          raw              "Result"
          payload_template "Parameters"
          path             "InputPath", :default => "$"
          path             "OutputPath", :default => "$"
          reference_path   "ResultPath", :default => "$"

          require_set "Next", "End"
        end

        def finish(context)
          input = result.nil? ? process_input(context) : result
          context.output = process_output(context, input)
          super
        end

        def running?(_)
          false
        end

        def end?
          @end
        end
      end
    end
  end
end
