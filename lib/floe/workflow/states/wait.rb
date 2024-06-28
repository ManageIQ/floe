# frozen_string_literal: true

require 'time'

module Floe
  class Workflow
    module States
      class Wait < Floe::Workflow::State
        include NonTerminalMixin

        fields do
          state_ref "Next"
          boolean "End"
          number "Seconds"
          timestamp "Timestamp"
          path "TimestampPath"
          path "SecondsPath"
          path "InputPath", :default => "$"
          path "OutputPath", :default => "$"

          require_set "Next", "End"
          require_set "Seconds", "Timestamp", "TimestampPath", "SecondsPath"
        end

        def initialize(workflow, name, payload)
          super

          load_fields(payload, workflow)
        end

        def start(context)
          super

          input = input_path.value(context, context.input)

          wait_until!(
            context,
            :seconds => seconds_path ? seconds_path.value(context, input).to_i : seconds,
            :time    => timestamp_path ? timestamp_path.value(context, input) : timestamp
          )
        end

        def finish(context)
          input          = input_path.value(context, context.input)
          context.output = output_path.value(context, input)
          super
        end

        def running?(context)
          waiting?(context)
        end

        def end?
          @end
        end
      end
    end
  end
end
