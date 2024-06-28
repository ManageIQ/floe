# frozen_string_literal: true

require 'time'

module Floe
  class Workflow
    module States
      class Wait < Floe::Workflow::State
        include NonTerminalMixin

        attr_reader :end, :input_path, :next, :seconds, :seconds_path, :timestamp, :timestamp_path, :output_path

        def initialize(workflow, name, payload)
          super

          @next           = state_ref!("Next", payload["Next"], workflow)
          @end            = boolean!("End", payload["End"])
          @seconds        = payload["Seconds"]&.to_i
          @timestamp      = payload["Timestamp"]
          @timestamp_path = path!("TimestampPath", payload["TimestampPath"])
          @seconds_path   = path!("SecondsPath", payload["SecondsPath"])

          @input_path     = path!("InputPath", payload.fetch("InputPath", "$"))
          @output_path    = path!("OutputPath", payload.fetch("OutputPath", "$"))

          require_fields!("Next" => @next, "End" => @end)
          require_fields!("Seconds" => @seconds, "Timestamp" => @timestamp, "TimestampPath" => @timestamp_path, "SecondsPath" => @seconds_path)
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
