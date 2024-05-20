# frozen_string_literal: true

module Floe
  class Workflow
    class ItemProcessor < Floe::WorkflowBase
      attr_reader :processor_config

      def initialize(payload, name = nil)
        super
        @processor_config = payload.fetch("ProcessorConfig", "INLINE")
      end

      def value(_context, input = {})
        # TODO: Run the states to get the output
        input
      end
    end
  end
end
