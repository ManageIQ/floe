# frozen_string_literal: true

module Floe
  class Workflow
    module States
      class Task < Floe::Workflow::State
        include InputOutputMixin
        include NonTerminalMixin
        include RetryCatchMixin

        attr_reader :credentials, :end, :heartbeat_seconds, :next, :parameters,
                    :result_selector, :resource, :timeout_seconds, :retry, :catch,
                    :input_path, :output_path, :result_path

        def initialize(workflow, name, payload)
          super

          @heartbeat_seconds = payload["HeartbeatSeconds"]
          @next              = payload["Next"]
          @end               = !!payload["End"]
          @resource          = payload["Resource"]

          missing_field_error!("Resource") unless @resource.kind_of?(String)
          @runner = wrap_parser_error("Resource", @resource) { Floe::Runner.for_resource(@resource) }

          @timeout_seconds   = payload["TimeoutSeconds"]
          @retry             = payload["Retry"].to_a.map.with_index { |retrier, i| Retrier.new(workflow, name + ["Retry", i.to_s], retrier) }
          @catch             = payload["Catch"].to_a.map.with_index { |catcher, i| Catcher.new(workflow, name + ["Catch", i.to_s], catcher) }
          @input_path        = Path.new(payload.fetch("InputPath", "$"))
          @output_path       = Path.new(payload.fetch("OutputPath", "$"))
          @result_path       = ReferencePath.new(payload.fetch("ResultPath", "$"))
          @parameters        = PayloadTemplate.new(payload["Parameters"])     if payload["Parameters"]
          @result_selector   = PayloadTemplate.new(payload["ResultSelector"]) if payload["ResultSelector"]
          @credentials       = PayloadTemplate.new(payload["Credentials"])    if payload["Credentials"]

          validate_state!(workflow)
        end

        def start(context)
          super

          input          = process_input(context)
          secrets        = credentials&.value(context, context.input)
          runner_context = runner.run_async!(resource, input, secrets, context)

          context.state["RunnerContext"] = runner_context
        end

        def finish(context)
          output = runner.output(context.state["RunnerContext"])

          if success?(context)
            output = parse_output(output)
            context.output = process_output(context, output)
          else
            error = parse_error(output)
            retry_state!(context, error) || catch_error!(context, error) || fail_workflow!(context, error)
          end
          super
        ensure
          runner.cleanup(context.state["RunnerContext"])
        end

        def running?(context)
          return true  if waiting?(context)
          return false if finished?(context)

          runner.status!(context.state["RunnerContext"])
          runner.running?(context.state["RunnerContext"])
        end

        def end?
          @end
        end

        private

        attr_reader :runner

        def validate_state!(workflow)
          validate_state_next!(workflow)
        end

        def success?(context)
          runner.success?(context.state["RunnerContext"])
        end

        def parse_error(output)
          return if output.nil?
          return output if output.kind_of?(Hash)

          JSON.parse(output.split("\n").last)
        rescue JSON::ParserError
          {"Error" => output.chomp}
        end

        def parse_output(output)
          return output if output.kind_of?(Hash)
          return if output.nil? || output.empty?

          JSON.parse(output.split("\n").last)
        rescue JSON::ParserError
          nil
        end
      end
    end
  end
end
