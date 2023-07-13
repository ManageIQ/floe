# frozen_string_literal: true

module Floe
  class Workflow
    module States
      class Succeed < Floe::Workflow::State
        def end?
          true # TODO: Handle if this is ending a parallel or map state
        end

        private

        def execute!(input)
          input
        end
      end
    end
  end
end
