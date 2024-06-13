# frozen_string_literal: true

module Floe
  class Workflow
    class Catcher
      attr_reader :error_equals, :next, :result_path

      def initialize(validator, payload)
        @payload = payload

        @error_equals = validator.validate_list!("ErrorEquals", payload["ErrorEquals"])
        @next         = validator.validate_state_ref!("Next", payload["Next"])
        @result_path  = ReferencePath.new(payload.fetch("ResultPath", "$"))
      end
    end
  end
end
