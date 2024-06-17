# frozen_string_literal: true

module Floe
  class Workflow
    module States
      class Pass < Floe::Workflow::State
        include InputOutputMixin
        include NonTerminalMixin

        attr_reader :end, :next, :result, :parameters, :input_path, :output_path, :result_path

        def initialize(workflow, name, payload)
          super

          @end         = payload.boolean!("End", :default => false)
          @next        = payload.state_ref!("Next", :optional => @end)
          @result      = payload["Result"]

          @parameters  = payload.payload_template!("Parameters", :default => nil)
          @input_path  = payload.path!("InputPath", :default => "$")
          @output_path = payload.path!("OutputPath", :default => "$")
          @result_path = payload.reference_path!("ResultPath", :default => "$")
        end

        def finish
          context.output = process_output(context.input.dup, result)
          super
        end

        def running?
          false
        end

        def end?
          @end
        end
      end
    end
  end
end
