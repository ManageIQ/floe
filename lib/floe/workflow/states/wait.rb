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

          @end            = payload.boolean!("End")
          @next           = payload.state_ref!("Next", :required => !@end)
          @seconds        = payload.number!("Seconds")
          @timestamp      = payload.timestamp!("Timestamp")
          @timestamp_path = payload.path!("TimestampPath", :default => nil)
          @seconds_path   = payload.path!("SecondsPath", :default => nil)

          if [seconds, timestamp, timestamp_path, seconds_path].compact.size != 1
            payload.error!("requires one field: \"Seconds\", \"Timestamp\", \"TimestampPath\", or \"SecondsPath\"")
          end

          @input_path  = payload.path!("InputPath", :default => "$")
          @output_path = payload.path!("OutputPath", :default => "$")

          payload.no_unreferenced_fields!
        end

        def start(context)
          super

          input = input_path.value(context, context.input)

          # TODO: typecheck seconds_path.value and timestamp_path.value
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
