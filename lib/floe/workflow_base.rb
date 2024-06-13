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

    def run(context)
      run_nonblock(context) until context.ended?
    end

    def run_nonblock(context)
      start_workflow(context)
      loop while step_nonblock(context) == 0 && !context.ended?
      self
    end

    def step_nonblock(context)
      return Errno::EPERM if context.ended?

      result = current_state(context).run_nonblock!(context)
      return result if result != 0

      context.state_history << context.state
      context.next_state ? step!(context) : end_workflow!(context)

      result
    end

    def step_nonblock_ready?(context)
      !context.started? || current_state(context).ready?(context)
    end

    def start_workflow(context)
      return if context.state_name

      context.state["Name"]  = start_at
      context.state["Input"] = context.execution["Input"].dup

      context.execution["StartTime"] = Time.now.utc.iso8601

      self
    end

    def current_state(context)
      states_by_name[context.state_name]
    end

    private

    def step!(context)
      next_state = {"Name" => context.next_state}

      # if rerunning due to an error (and we are using Retry)
      if context.state_name == context.next_state && context.failed? && context.state.key?("Retrier")
        next_state.merge!(context.state.slice("RetryCount", "Input", "Retrier"))
      else
        next_state["Input"] = context.output
      end

      context.state = next_state
    end

    # Avoiding State#running? because that is potentially expensive.
    # State#run_nonblock! already called running? via State#ready? and
    # called State#finished -- which is what Context#state_finished? is detecting
    def end_workflow!(context)
      context.execution["EndTime"] = context.state["FinishedTime"]
    end
  end
end
