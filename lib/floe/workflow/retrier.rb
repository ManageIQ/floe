# frozen_string_literal: true

module Floe
  class Workflow
    class Retrier
      include ErrorMatcherMixin
      include ValidationMixin

      attr_reader :error_equals, :interval_seconds, :max_attempts, :backoff_rate, :full_name

      def initialize(_workflow, full_name, payload)
        @full_name        = full_name
        @payload          = payload

        @error_equals     = payload["ErrorEquals"]
        @interval_seconds = payload["IntervalSeconds"] || 1.0
        @max_attempts     = payload["MaxAttempts"] || 3
        @backoff_rate     = payload["BackoffRate"] || 2.0
        raise Floe::InvalidWorkflowError, "State requires ErrorEquals" if !@error_equals.kind_of?(Array) || @error_equals.empty?
      end

      # @param [Integer] attempt 1 for the first attempt
      def sleep_duration(attempt)
        interval_seconds * (backoff_rate**(attempt - 1))
      end
    end
  end
end
