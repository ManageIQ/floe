# frozen_string_literal: true

module Floe
  class WorkflowBase
    include ValidationMixin

    attr_reader :name, :payload, :start_at, :states, :states_by_name

    def initialize(payload, name = nil)
      # NOTE: this is a string, and states use an array
      @name     = name || "State Machine"
      @payload  = payload
      @start_at = payload["StartAt"]

      # NOTE: Everywhere else we include our name (i.e.: parent name) when building the child name.
      #       When creating the states, we are dropping our name (i.e.: the workflow name)
      @states         = payload["States"].to_a.map { |state_name, state| Floe::Workflow::State.build!(self, ["States", state_name], state) }
      @states_by_name = @states.to_h { |state| [state.short_name, state] }

      validate_workflow!
    end

    private

    def validate_workflow!
      missing_field_error!("States") if @states.empty?
      missing_field_error!("StartAt") if @start_at.nil?
      invalid_field_error!("StartAt", @start_at, "is not found in \"States\"") unless workflow_state?(@start_at, self)
    end
  end
end
