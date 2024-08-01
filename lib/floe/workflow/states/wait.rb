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

          @next           = payload["Next"]
          @end            = !!payload["End"]
          @seconds        = payload["Seconds"]&.to_i
          @timestamp      = payload["Timestamp"]
          @timestamp_path = wrap_parser_error("TimestampPath", payload["TimestampPath"]) { Path.new(payload["TimestampPath"]) } if payload.key?("TimestampPath")
          @seconds_path   = wrap_parser_error("SecondsPath", payload["SecondsPath"]) { Path.new(payload["SecondsPath"]) } if payload.key?("SecondsPath")
          @input_path     = wrap_parser_error("InputPath", payload["InputPath"]) { Path.new(payload.fetch("InputPath", "$")) }
          @output_path    = wrap_parser_error("OutputPath", payload["OutputPath"]) { Path.new(payload.fetch("OutputPath", "$")) }

          validate_state!(workflow)
        end

        def start(context)
          super

          input = wrap_runtime_error("InputPath", input_path.to_s) { input_path.value(context, context.input) }

          wait_until!(
            context,
            :seconds => seconds_path ? seconds_path.value(context, input).to_i : seconds,
            :time    => timestamp_path ? timestamp_path.value(context, input) : timestamp
          )
        end

        def finish(context)
          input          = wrap_runtime_error("InputPath", input_path.to_s) { input_path.value(context, context.input) }
          context.output = wrap_runtime_error("OutputPath", input_path.to_s) { output_path.value(context, input) }
          super
        end

        def running?(context)
          waiting?(context)
        end

        def end?
          @end
        end

        private

        def validate_state!(workflow)
          validate_state_next!(workflow)
        end
      end
    end
  end
end
