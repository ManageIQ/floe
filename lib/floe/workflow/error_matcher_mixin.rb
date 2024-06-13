# frozen_string_literal: true

module Floe
  class Workflow
    # Methods for common error handling
    module ErrorMatcherMixin
      attr_reader :error_equals

      def initialize(payload)
        @error_equals = payload["ErrorEquals"]
        raise Floe::InvalidWorkflowError, "State requires ErrorEquals" if !@error_equals.kind_of?(Array) || @error_equals.empty?
      end

      # @param [String] error the error thrown
      def match_error?(error)
        return false if error == "States.Runtime"
        return true if error_equals.include?("States.ALL")
        return true if error_equals.include?("States.Timeout") && error == "States.HeartbeatTimeout"

        error_equals.include?(error)
      end
    end
  end
end
