# frozen_string_literal: true

require 'time'

module Floe
  class Workflow
    module States
      class Wait < Floe::Workflow::State
        include NonTerminalMixin

        attr_reader :input_path, :seconds, :seconds_path, :timestamp, :timestamp_path, :output_path

        def initialize(workflow, name, payload)
          super

          validator = workflow.validator.for_state(name)

          @end            = !!payload["End"]
          @next           = validator.validate_state_ref!("Next", payload["Next"], :optional => @end)
          @seconds        = payload["Seconds"]&.to_i
          @timestamp      = payload["Timestamp"]
          @timestamp_path = Path.new(payload["TimestampPath"]) if payload.key?("TimestampPath")
          @seconds_path   = Path.new(payload["SecondsPath"]) if payload.key?("SecondsPath")

          @input_path  = Path.new(payload.fetch("InputPath", "$"))
          @output_path = Path.new(payload.fetch("OutputPath", "$"))
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
