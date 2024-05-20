# frozen_string_literal: true

module Floe
  class WorkflowBase
    attr_reader :name, :payload, :start_at, :states, :states_by_name

    def initialize(payload, name = nil)
      raise Floe::InvalidWorkflowError, "Missing field \"States\" for state [#{name}]"  if payload["States"].nil?
      raise Floe::InvalidWorkflowError, "Missing field \"StartAt\" for state [#{name}]" if payload["StartAt"].nil?
      raise Floe::InvalidWorkflowError, "\"StartAt\" not in the \"States\" field for state [#{name}]" unless payload["States"].key?(payload["StartAt"])

      @payload        = payload
      @name           = name
      @start_at       = payload["StartAt"]
      @states         = payload["States"].to_a.map { |state_name, state| Floe::Workflow::State.build!(self, state_name, state) }
      @states_by_name = @states.to_h { |state| [state.name, state] }
    end
  end
end
