# frozen_string_literal: true

module Floe
  class Workflow
    class Retrier
      include ValidationMixin

      attr_reader :full_name

      fields do
        list   "ErrorEquals", :required => true
        number "IntervalSeconds", :default => 1.0
        number "MaxAttempts", :default => 3
        number "BackoffRate", :default => 2.0
      end

      def initialize(workflow, full_name, payload)
        @full_name = full_name

        load_fields(payload, workflow)
      end

      # @param [Integer] attempt 1 for the first attempt
      def sleep_duration(attempt)
        interval_seconds * (backoff_rate**(attempt - 1))
      end
    end
  end
end
