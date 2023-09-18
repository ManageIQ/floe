# frozen_string_literal: true

module Floe
  class Workflow
    module States
      class Succeed < Floe::Workflow::State
        attr_reader :input_path, :output_path

        def run!(context)
          context.end_state!(context.input)
        end

        def end?
          true
        end
      end
    end
  end
end
