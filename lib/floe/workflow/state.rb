# frozen_string_literal: true

module Floe
  class Workflow
    class State
      include Logging
      include ValidationMixin

      class << self
        def build!(workflow, full_name, payload)
          state_type = build_validate_type!(full_name, payload["Type"])

          begin
            klass = Floe::Workflow::States.const_get(state_type)
          rescue NameError
            error!(full_name, "requires field \"Type\" but got invalid value [#{state_type}]")
          end

          klass.new(workflow, full_name, payload)
        end

        private

        def build_validate_type!(full_name, state_type)
          if full_name.last.length > 80
            full_name[-1] = "#{full_name.last[0..79]}..."
            error!(full_name, "State name must be less than or equal to 80 characters")
          end

          error!(full_name, "requires field \"Type\"") if state_type.nil? || state_type.empty?
          error!(full_name, "requires String field \"Type\" but got #{state_type.class}") unless state_type.kind_of?(String)

          state_type
        end
      end

      attr_reader :full_name, :payload

      fields do
        string "Type"
        string "Comment"
      end

      def initialize(_workflow, full_name, payload)
        @full_name = full_name
        @payload   = payload

        # NOTE: requires child class to call: load_fields(payload, workflow)
      end

      def wait(context, timeout: nil)
        start = Time.now.utc

        loop do
          return 0             if ready?(context)
          return Errno::EAGAIN if timeout && (timeout.zero? || Time.now.utc - start > timeout)

          sleep(1)
        end
      end

      # @return for incomplete Errno::EAGAIN, for completed 0
      def run_nonblock!(context)
        start(context) unless context.state_started?
        return Errno::EAGAIN unless ready?(context)

        finish(context)
      end

      def start(context)
        context.state["EnteredTime"] = Time.now.utc.iso8601

        logger.info("Running state: [#{long_name}] with input [#{context.input}]...")
      end

      def finish(context)
        finished_time     = Time.now.utc
        entered_time      = Time.parse(context.state["EnteredTime"])

        context.state["FinishedTime"] ||= finished_time.iso8601
        context.state["Duration"]       = finished_time - entered_time

        level = context.failed? ? :error : :info
        logger.public_send(level, "Running state: [#{long_name}] with input [#{context.input}]...Complete #{context.next_state ? "- next state [#{context.next_state}]" : "workflow -"} output: [#{context.output}]")

        0
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

      def wait_until(context)
        context.state["WaitUntil"] && Time.parse(context.state["WaitUntil"])
      end

      def name
        full_name.last
      end

      def long_name
        "#{type}:#{name}"
      end

      private

      def wait_until!(context, seconds: nil, time: nil)
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
