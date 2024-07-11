# frozen_string_literal: true

module Floe
  class Workflow
    class Catcher
      include ErrorMatcherMixin
      include ValidationMixin

      attr_reader :error_equals, :next, :result_path, :name

      def initialize(workflow, name, payload)
        @name         = name
        @payload      = payload

        @error_equals = payload["ErrorEquals"]
        @next         = payload["Next"]
        @result_path  = wrap_parser_error("ResultPath", payload.fetch("ResultPath", nil)) { ReferencePath.new(payload.fetch("ResultPath", "$")) }

        missing_field_error!("ErrorEquals") if !@error_equals.kind_of?(Array) || @error_equals.empty?
        validate_state_next!(workflow)
      end

      private

      def validate_state_next!(workflow)
        missing_field_error!("Next") if @next.nil?
        invalid_field_error!("Next", @next, "is not found in \"States\"") if @next && !workflow_state?(@next, workflow)
      end
    end
  end
end
