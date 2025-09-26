# frozen_string_literal: true

module Floe
  class Workflow
    module States
      module InputOutputMixin
        def process_input(context)
          input = wrap_runtime_error("InputPath", input_path.to_s) { input_path.value(context, context.input) }
          input = wrap_runtime_error("Parameters", parameters.to_s) { parameters.value(context, input) } if parameters
          input
        end

        def process_output(context, results)
          return context.input.dup if results.nil?
          return if output_path.nil?

          results = wrap_runtime_error("ResultSelector", @result_selector.to_s) { result_selector.value(context, results) } if @result_selector
          if result_path.payload.match?(/^\$\$\.Credentials\b/)
            credentials = wrap_runtime_error("ResultPath", result_path.to_s) { result_path.set(context.credentials, results) }
            context.credentials.merge!(credentials) if credentials
            output = context.input.dup
          else
            output = result_path.set(context.input.dup, results)
          end

          wrap_runtime_error("OutputPath", output_path.to_s) { output_path.value(context, output) }
        end
      end
    end
  end
end
