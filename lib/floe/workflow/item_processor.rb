# frozen_string_literal: true

module Floe
  class Workflow
    class ItemProcessor
      attr_reader :processor_config, :payload, :states, :start_at

      def initialize(payload, name = nil)
        @payload = payload
        @name    = name

        raise Floe::InvalidWorkflowError, "Missing field \"States\" for state [#{name}]"  if payload["States"].nil?
        raise Floe::InvalidWorkflowError, "Missing field \"StartAt\" for state [#{name}]" if payload["StartAt"].nil?
        raise Floe::InvalidWorkflowError, "\"StartAt\" not in the \"States\" field for state [#{name}]" unless payload["States"].key?(payload["StartAt"])

        @processor_config = payload.fetch("ProcessorConfig", "INLINE")
        @states           = payload["States"].to_a.map { |state_name, state| State.build!(self, state_name, state) }
        @states_by_name   = @states.to_h { |state| [state.name, state] }
      end

      def value(_context, input = {})
        # TODO: Run the states to get the output
        input
      end
    end
  end
end
