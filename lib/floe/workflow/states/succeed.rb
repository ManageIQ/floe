# frozen_string_literal: true

module Floe
  class Workflow
    module States
      class Succeed < Floe::Workflow::State
        attr_reader :input_path, :output_path

        def initialize(workflow, name, payload)
          super

          @input_path = payload.field!("InputPath", :default => nil)
          @output_path = payload.field!("OutputPath", :default => nil)
        end

        def finish
          context.next_state = nil
          context.output     = context.input
          super
        end

        def running?
          false
        end

        def end?
          true
        end
      end
    end
  end
end
