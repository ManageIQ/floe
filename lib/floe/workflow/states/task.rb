# frozen_string_literal: true

module Floe
  class Workflow
    module States
      class Task < Floe::Workflow::State
        include InputOutputMixin
        include NonTerminalMixin

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
          @input_path        = wrap_parser_error("InputPath", payload.fetch("InputPath", nil)) { Path.new(payload.fetch("InputPath", "$")) }
          @output_path       = wrap_parser_error("OutputPath", payload.fetch("OutputPath", nil)) { Path.new(payload.fetch("OutputPath", "$")) }
          @result_path       = wrap_parser_error("ResultPath", payload.fetch("ResultPath", nil)) { ReferencePath.new(payload.fetch("ResultPath", "$")) }
          @parameters        = wrap_parser_error("Parameters", payload["Parameters"]) { PayloadTemplate.new(payload["Parameters"]) }             if payload["Parameters"]
          @result_selector   = wrap_parser_error("ResultSelector", payload["ResultSelector"]) { PayloadTemplate.new(payload["ResultSelector"]) } if payload["ResultSelector"]
          @credentials       = wrap_parser_error("Credentials", payload["Credentials"]) { PayloadTemplate.new(payload["Credentials"]) }          if payload["Credentials"]

          validate_state!(workflow)
        end

        def start(context)
          super

          input          = process_input(context)
          runner_context = runner.run_async!(resource, input, credentials&.value({}, context.credentials), context)

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
          return true if waiting?(context)

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

        def find_retrier(error)
          self.retry.detect { |r| r.match_error?(error) }
        end

        def find_catcher(error)
          self.catch.detect { |c| c.match_error?(error) }
        end

        def retry_state!(context, error)
          retrier = find_retrier(error["Error"]) if error
          return if retrier.nil?

          # If a different retrier is hit reset the context
          if !context["State"].key?("RetryCount") || context["State"]["Retrier"] != retrier.error_equals
            context["State"]["RetryCount"] = 0
            context["State"]["Retrier"]    = retrier.error_equals
          end

          context["State"]["RetryCount"] += 1

          return if context["State"]["RetryCount"] > retrier.max_attempts

          wait_until!(context, :seconds => retrier.sleep_duration(context["State"]["RetryCount"]))
          context.next_state = context.state_name
          context.output     = error
          logger.info("Running state: [#{long_name}] with input [#{context.json_input}] got error[#{context.json_output}]...Retry - delay: #{wait_until(context)}")
          true
        end

        def catch_error!(context, error)
          catcher = find_catcher(error["Error"]) if error
          return if catcher.nil?

          context.next_state = catcher.next
          context.output     = wrap_runtime_error("ResultPath", result_path.to_s) { catcher.result_path.set(context.input, error) }
          logger.info("Running state: [#{long_name}] with input [#{context.json_input}]...CatchError - next state: [#{context.next_state}] output: [#{context.json_output}]")

          true
        end

        def fail_workflow!(context, error)
          # next_state is nil, and will be set to nil again in super
          # keeping in here for completeness
          context.next_state = nil
          context.output = error
          logger.error("Running state: [#{long_name}] with input [#{context.json_input}]...Complete workflow - output: [#{context.json_output}]")
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
