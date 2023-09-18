# frozen_string_literal: true

module Floe
  class Workflow
    module States
      class Succeed < Floe::Workflow::State
        attr_reader :input_path, :output_path

        def initialize(workflow, name, payload)
          super
        end

        def run!(_input)
          context.end_state!(context.input)
        end

        def end?
          true
        end
      end
    end
  end
end
