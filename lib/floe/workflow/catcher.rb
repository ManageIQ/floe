# frozen_string_literal: true

module Floe
  class Workflow
    class Catcher
      include Floe::Workflow::ErrorMatcherMixin

      attr_reader :next, :result_path

      def initialize(payload)
        @payload = payload

        @error_equals = payload["ErrorEquals"]
        @next         = payload["Next"]
        @result_path  = ReferencePath.new(payload.fetch("ResultPath", "$"))

        super
      end
    end
  end
end
