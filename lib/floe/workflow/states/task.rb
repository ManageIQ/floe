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

          @heartbeat_seconds = payload.number!("HeartbeatSeconds")
          @end               = payload.boolean!("End")
          @next              = payload.state_ref!("Next", :required => !@end)
          @resource          = payload.string!("Resource")
          @runner            = Floe::Runner.for_resource(@resource)
          @timeout_seconds   = payload.number!("TimeoutSeconds")
          @retry             = payload.list!("Retry", :required => false).map { |retrier| Retrier.new(payload.for_rule("Retry", retrier)) }
          @catch             = payload.list!("Catch", :required => false).map { |catcher| Catcher.new(payload.for_rule("Catch", catcher)) }
          @input_path        = payload.path!("InputPath", :default => "$")
          @output_path       = payload.path!("OutputPath", :default => "$")
          @result_path       = payload.reference_path!("ResultPath", :default => "$")
          @parameters        = payload.payload_template!("Parameters", :default => nil)
          @result_selector   = payload.payload_template!("ResultSelector", :default => nil)
          @credentials       = payload.payload_template!("Credentials", :default => nil)

          payload.no_unreferenced_fields!
        rescue ArgumentError => err
          raise Floe::InvalidWorkflowError, err.message
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

        def success?(context)
          runner.success?(context.state["RunnerContext"])
        end

        def find_retrier(error)
          self.retry.detect { |r| (r.error_equals & [error, "States.ALL"]).any? }
        end

        def find_catcher(error)
          self.catch.detect { |c| (c.error_equals & [error, "States.ALL"]).any? }
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
          logger.info("Running state: [#{long_name}] with input [#{context.input}] got error[#{context.output}]...Retry - delay: #{wait_until(context)}")
          true
        end

        def catch_error!(context, error)
          catcher = find_catcher(error["Error"]) if error
          return if catcher.nil?

          context.next_state = catcher.next
          context.output     = catcher.result_path.set(context.input, error)
          logger.info("Running state: [#{long_name}] with input [#{context.input}]...CatchError - next state: [#{context.next_state}] output: [#{context.output}]")

          true
        end

        def fail_workflow!(context, error)
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
