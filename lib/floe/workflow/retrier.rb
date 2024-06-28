# frozen_string_literal: true

module Floe
  class Workflow
    class Retrier
      include ValidationMixin

      attr_reader :error_equals, :interval_seconds, :max_attempts, :backoff_rate, :full_name

      def initialize(workflow, full_name, payload)
        @full_name        = full_name
        @payload          = payload

        @error_equals     = list!("ErrorEquals", payload["ErrorEquals"], workflow)
        @interval_seconds = number!("IntervalSeconds", payload.fetch("IntervalSeconds", 1.0))
        @max_attempts     = number!("MaxAttempts", payload.fetch("MaxAttempts", 3))
        @backoff_rate     = number!("BackoffRate", payload.fetch("BackoffRate", 2.0))

        require_fields!("ErrorEquals" => @error_equals)
      end

      # @param [Integer] attempt 1 for the first attempt
      def sleep_duration(attempt)
        interval_seconds * (backoff_rate**(attempt - 1))
      end
    end
  end
end
