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

          validator = workflow.validator.for_state(name)

          validator.validate_list!("Retry", payload["Retry"], :optional => true)
          validator.validate_list!("Catch", payload["Catch"], :optional => true)

          @heartbeat_seconds = payload["HeartbeatSeconds"]
          @end               = !!payload["End"]
          @next              = validator.validate_state_ref!("Next", payload["Next"], :optional => @end)
          @resource          = payload["Resource"]
          @runner            = Floe::Runner.for_resource(@resource)
          @timeout_seconds   = payload["TimeoutSeconds"]
          @retry             = payload["Retry"].to_a.map { |retrier| Retrier.new(validator.for_state(name, :rule => "Retry"), retrier) }
          @catch             = payload["Catch"].to_a.map { |catcher| Catcher.new(validator.for_state(name, :rule => "Catcher"), catcher) }
          @input_path        = Path.new(payload.fetch("InputPath", "$"))
          @output_path       = Path.new(payload.fetch("OutputPath", "$"))
          @result_path       = ReferencePath.new(payload.fetch("ResultPath", "$"))
          @parameters        = PayloadTemplate.new(payload["Parameters"])     if payload["Parameters"]
          @result_selector   = PayloadTemplate.new(payload["ResultSelector"]) if payload["ResultSelector"]
          @credentials       = PayloadTemplate.new(payload["Credentials"])    if payload["Credentials"]
        end

        def start(context)
          super

          input          = process_input(context.input)
          runner_context = runner.run_async!(resource, input, credentials&.value({}, context.credentials), context)

          context.state["RunnerContext"] = runner_context
        end

        def finish(context)
          output = runner.output(context.state["RunnerContext"])

          if success?
            output = parse_output(output)
            context.output = process_output(context.input.dup, output)
          else
            error = parse_error(output)
            retry_state!(error) || catch_error!(error) || fail_workflow!(error)
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

        def success?
          runner.success?(context.state["RunnerContext"])
        end

        def find_retrier(error)
          self.retry.detect { |r| (r.error_equals & [error, "States.ALL"]).any? }
        end

        def find_catcher(error)
          self.catch.detect { |c| (c.error_equals & [error, "States.ALL"]).any? }
        end

        def retry_state!(error)
          retrier = find_retrier(error["Error"]) if error
          return if retrier.nil?

          # If a different retrier is hit reset the context
          if !context["State"].key?("RetryCount") || context["State"]["Retrier"] != retrier.error_equals
            context["State"]["RetryCount"] = 0
            context["State"]["Retrier"]    = retrier.error_equals
          end

          context["State"]["RetryCount"] += 1

          return if context["State"]["RetryCount"] > retrier.max_attempts

          wait_until!(:seconds => retrier.sleep_duration(context["State"]["RetryCount"]))
          context.next_state = context.state_name
          context.output     = error
          logger.info("Running state: [#{long_name}] with input [#{context.input}] got error[#{context.output}]...Retry - delay: #{wait_until}")
          true
        end

        def catch_error!(error)
          catcher = find_catcher(error["Error"]) if error
          return if catcher.nil?

          context.next_state = catcher.next
          context.output     = catcher.result_path.set(context.input, error)
          logger.info("Running state: [#{long_name}] with input [#{context.input}]...CatchError - next state: [#{context.next_state}] output: [#{context.output}]")

          true
        end

        def fail_workflow!(error)
          # next_state is nil, and will be set to nil again in super
          # keeping in here for completeness
          context.next_state = nil
          context.output = error
          logger.error("Running state: [#{long_name}] with input [#{context.input}]...Complete workflow - output: [#{context.output}]")
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
