# frozen_string_literal: true

module Floe
  class Workflow
    class State
      include Logging

      class << self
        def build!(workflow, name, payload)
          state_type = payload["Type"]
          raise Floe::InvalidWorkflowError, "Missing \"Type\" field in state [#{name}]" if payload["Type"].nil?

          begin
            klass = Floe::Workflow::States.const_get(state_type)
          rescue NameError
            raise Floe::InvalidWorkflowError, "Invalid state type: [#{state_type}]"
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

        raise Floe::InvalidWorkflowError, "Missing \"Type\" field in state [#{name}]" if payload["Type"].nil?
        raise Floe::InvalidWorkflowError, "State name [#{name}] must be less than or equal to 80 characters" if name.length > 80
      end

      def run_nonblock!
        start(context.input) unless started?
        return Errno::EAGAIN unless ready?

        finish
      end

      def start(_input)
        start_time = Time.now.utc.iso8601

        context.execution["StartTime"] ||= start_time
        context.state["Guid"]            = SecureRandom.uuid
        context.state["EnteredTime"]     = start_time

        logger.info("Running state: [#{long_name}] with input [#{context.input}]...")
      end

      def finish
        finished_time     = Time.now.utc
        finished_time_iso = finished_time.iso8601
        entered_time      = Time.parse(context.state["EnteredTime"])

        context.state["FinishedTime"] ||= finished_time_iso
        context.state["Duration"]       = finished_time - entered_time
        context.execution["EndTime"]    = finished_time_iso if context.next_state.nil?

        level = context.output&.[]("Error") ? :error : :info
        logger.public_send(level, "Running state: [#{long_name}] with input [#{context.input}]...Complete #{context.next_state ? "- next state [#{context.next_state}]" : "workflow -"} output: [#{context.output}]")

        context.state_history << context.state

        0
      end

      def context
        workflow.context
      end

      def started?
        context.state.key?("EnteredTime")
      end

      def ready?
        !started? || !running?
      end

      def finished?
        context.state.key?("FinishedTime")
      end

      def waiting?
        context.state["WaitUntil"] && Time.now.utc <= Time.parse(context.state["WaitUntil"])
      end

      def wait_until
        context.state["WaitUntil"] && Time.parse(context.state["WaitUntil"])
      end

      def long_name
        "#{self.class.name.split("::").last}:#{name}"
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
