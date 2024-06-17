# frozen_string_literal: true

module Floe
  class Workflow
    module States
      # Methods for common input output handling
      module InputOutputMixin
        attr_reader :parameters, :input_path, :output_path, :result_path, :result_selector

        def initialize(workflow, name, payload)
          super

          @input_path      = Path.new(payload.fetch("InputPath", "$"))
          @output_path     = Path.new(payload.fetch("OutputPath", "$"))
          @result_path     = ReferencePath.new(payload.fetch("ResultPath", "$"))
          # NOTE: Map uses "ItemSelector" instead of "Parameters"
          @parameters      = PayloadTemplate.new(payload["Parameters"])     if payload["Parameters"]
          # NOTE: "ResultSelector" is not valid for Pass
          @result_selector = PayloadTemplate.new(payload["ResultSelector"]) if payload["ResultSelector"]
        end

        def process_input(context)
          input = input_path.value(context, context.input)
          input = parameters.value(context, input) if parameters
          input
        end

        def process_output(context, results)
          return context.input.dup if results.nil?
          return if output_path.nil?

          results = result_selector.value(context, results) if @result_selector
          if result_path.payload.start_with?("$.Credentials")
            credentials = result_path.set(context.credentials, results)["Credentials"]
            context.credentials.merge!(credentials)
            output = context.input.dup
          else
            output = result_path.set(context.input.dup, results)
          end

          output_path.value(context, output)
        end
      end
    end
  end
end
