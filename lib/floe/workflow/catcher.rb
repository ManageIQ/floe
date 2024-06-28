# frozen_string_literal: true

module Floe
  class Workflow
    class Catcher
      include ErrorMatcherMixin
      include ValidationMixin

      attr_reader :error_equals, :next, :result_path, :full_name

      def initialize(workflow, full_name, payload)
        @full_name    = full_name
        @payload      = payload

        @error_equals = list!("ErrorEquals", payload["ErrorEquals"], workflow)
        @next         = state_ref!("Next", payload["Next"], workflow)
        @result_path  = reference_path!("ResultPath", payload.fetch("ResultPath", "$"))

        require_fields!("ErrorEquals" => @error_equals)
      end
    end
  end
end
