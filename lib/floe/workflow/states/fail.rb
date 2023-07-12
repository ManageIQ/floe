# frozen_string_literal: true

module Floe
  class Workflow
    module States
      class Fail < Floe::Workflow::State
        attr_reader :cause, :error

        def initialize(workflow, name, payload)
          super

          @cause = payload["Cause"]
          @error = payload["Error"]
        end

        def end?
          true
        end

        def status
          "errored"
        end

        private

        def execute!(_)
          nil
        end
      end
    end
  end
end
