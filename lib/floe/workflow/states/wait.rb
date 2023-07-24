# frozen_string_literal: true

module Floe
  class Workflow
    module States
      class Wait < Floe::Workflow::State
        attr_reader :seconds

        def initialize(workflow, name, payload)
          super

          @seconds = payload["Seconds"].to_i
        end

        def run_input!(input)
          sleep(seconds)
          input
        end
      end
    end
  end
end
