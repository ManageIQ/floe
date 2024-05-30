# frozen_string_literal: true

module Floe
  class Workflow
    module States
      class Succeed < Floe::Workflow::State
        attr_reader :input_path, :output_path

        def finish(context)
          context.next_state = nil
          context.output     = context.input
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
