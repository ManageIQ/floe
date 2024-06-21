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

          @end         = payload.boolean!("End")
          @next        = payload.state_ref!("Next", :required => !@end)
          @result      = payload["Result"]

          @parameters  = payload.payload_template!("Parameters", :default => nil)
          @input_path  = payload.path!("InputPath", :default => "$")
          @output_path = payload.path!("OutputPath", :default => "$")
          @result_path = payload.reference_path!("ResultPath", :default => "$")

          payload.no_unreferenced_fields!
        end

        def finish(context)
          context.output = process_output(context, result)
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
