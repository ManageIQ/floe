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

        def run!(input)
          [nil, input]
        end

        def terminal_state?
          true
        end

        def status
          "errored"
        end
      end
    end
  end
end
