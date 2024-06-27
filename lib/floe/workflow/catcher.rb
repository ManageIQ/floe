# frozen_string_literal: true

module Floe
  class Workflow
    class Catcher
      attr_reader :error_equals, :next, :result_path, :full_name

      def initialize(full_name, payload)
        @full_name    = full_name
        @payload      = payload

        @error_equals = payload["ErrorEquals"]
        @next         = payload["Next"]
        @result_path  = ReferencePath.new(payload.fetch("ResultPath", "$"))
      end
    end
  end
end
