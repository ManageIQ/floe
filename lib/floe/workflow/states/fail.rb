# frozen_string_literal: true

module Floe
  class Workflow
    module States
      class Fail < Floe::Workflow::State
        attr_reader :cause, :error

        def initialize(name, payload, _credentials = nil)
          super

          @cause = payload["Cause"]
          @error = payload["Error"]
        end

        def run!(context)
          context.end_state!(context.input, :error => @error, :cause => @cause)
        end

        def end?
          true
        end
      end
    end
  end
end
