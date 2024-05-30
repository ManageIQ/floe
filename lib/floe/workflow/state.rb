# frozen_string_literal: true

module Floe
  class Workflow
    class State
      include Logging

      class << self
        def build!(workflow, name, payload)
          validator = workflow.validator.for_state(name)
          state_type = payload["Type"]
          validator.validate_field!("Type", payload["Type"])

          begin
            klass = Floe::Workflow::States.const_get(state_type)
          rescue NameError
            validator.reject!("Type", state_type)
          end

          klass.new(workflow, name, payload)
        end
      end

      attr_reader :workflow, :comment, :name, :type, :payload

      def initialize(workflow, name, payload)
        @workflow = workflow
        @name     = name
        @payload  = payload
        @type     = payload["Type"]
        @comment  = payload["Comment"]

        # We should be using build so this should never get hit
        validator = workflow.validator.for_state(name)
        validator.validate_field!("Type", @type)
        raise Floe::InvalidWorkflowError, "State name [#{name[..79]}...] must be less than or equal to 80 characters" if name.length > 80
      end

      def wait(timeout: nil)
        start = Time.now.utc

        loop do
          return 0             if ready?(context)
          return Errno::EAGAIN if timeout && (timeout.zero? || Time.now.utc - start > timeout)

          sleep(1)
        end
      end

      # @return for incomplete Errno::EAGAIN, for completed 0
      def run_nonblock!
        start(context.input) unless context.state_started?
        return Errno::EAGAIN unless ready?(context)

        finish
      end

      def start(_input)
        context.state["Guid"]        = SecureRandom.uuid
        context.state["EnteredTime"] = Time.now.utc.iso8601

        logger.info("Running state: [#{long_name}] with input [#{context.input}]...")
      end

      def finish
        finished_time     = Time.now.utc
        entered_time      = Time.parse(context.state["EnteredTime"])

        context.state["FinishedTime"] ||= finished_time.iso8601
        context.state["Duration"]       = finished_time - entered_time

        level = context.output&.[]("Error") ? :error : :info
        logger.public_send(level, "Running state: [#{long_name}] with input [#{context.input}]...Complete #{context.next_state ? "- next state [#{context.next_state}]" : "workflow -"} output: [#{context.output}]")

        0
      end

      def context
        workflow.context
      end

      def ready?(context)
        !context.state_started? || !running?(context)
      end

      def running?(context)
        raise NotImplementedError, "Must be implemented in a subclass"
      end

      def waiting?(context)
        context.state["WaitUntil"] && Time.now.utc <= Time.parse(context.state["WaitUntil"])
      end

      def wait_until
        context.state["WaitUntil"] && Time.parse(context.state["WaitUntil"])
      end

      def long_name
        "#{payload["Type"]}:#{name}"
      end

      private

      def wait_until!(seconds: nil, time: nil)
        context.state["WaitUntil"] =
          if seconds
            (Time.parse(context.state["EnteredTime"]) + seconds).iso8601
          elsif time.kind_of?(String)
            time
          else
            time.iso8601
          end
      end
    end
  end
end
