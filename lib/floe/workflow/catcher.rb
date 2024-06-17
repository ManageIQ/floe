# frozen_string_literal: true

module Floe
  class Workflow
    class Catcher
      attr_reader :error_equals, :next, :result_path

      def initialize(payload)
        @payload = payload

        @error_equals = payload.list!("ErrorEquals")
        @next         = payload.state_ref!("Next")
        @result_path  = payload.reference_path!("ResultPath", :default => "$")
      end
    end
  end
end
