# frozen_string_literal: true

module Floe
  class Workflow
    module States
      class Succeed < Floe::Workflow::State
        fields do
          path "InputPath", :default => "$"
          path "OutputPath", :default => "$"
        end

        def initialize(workflow, name, payload)
          super

          load_fields(payload, workflow)
        end

        def finish(context)
          input              = input_path.value(context, context.input)
          context.output     = output_path.value(context, input)
          context.next_state = nil

          super
        end

        def running?(_)
          false
        end

        def end?
          true
        end
      end
    end
  end
end
