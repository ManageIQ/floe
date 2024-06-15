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

          @end            = payload.boolean!("End", :default => false)
          @next           = payload.state_ref!("Next", :optional => @end)
          @seconds        = payload["Seconds"]&.to_i
          @timestamp      = payload["Timestamp"]
          @timestamp_path = payload.path!("TimestampPath", :default => nil)
          @seconds_path   = payload.path!("SecondsPath", :default => nil)

          @input_path  = payload.path!("InputPath", :default => "$")
          @output_path = payload.path!("OutputPath", :default => "$")

          payload.no_unreferenced_fields!
        end

        def start(input)
          super

          input = input_path.value(context, context.input)

          wait_until!(
            :seconds => seconds_path ? seconds_path.value(context, input).to_i : seconds,
            :time    => timestamp_path ? timestamp_path.value(context, input) : timestamp
          )
        end

        def finish
          input          = input_path.value(context, context.input)
          context.output = output_path.value(context, input)
          super
        end

        def running?
          waiting?
        end

        def end?
          @end
        end
      end
    end
  end
end
