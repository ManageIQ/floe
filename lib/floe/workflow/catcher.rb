# frozen_string_literal: true

module Floe
  class Workflow
    class Catcher
      include ErrorMatcherMixin
      include ValidationMixin

      fields do
        list           "ErrorEquals", :required => true
        state_ref      "Next"
        reference_path "ResultPath", :default => "$"
      end

      def initialize(workflow, full_name, payload)
        @full_name = full_name
        @payload   = payload

        load_fields(payload, workflow)
      end
    end
  end
end
