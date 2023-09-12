# frozen_string_literal: true

module Floe
  class Workflow
    class Context
      def initialize(context = nil, input: {})
        context = JSON.parse(context) if context.kind_of?(String)

        @context = context || {
          "Execution"    => {
            "Input" => input
          },
          "State"        => {},
          "StateHistory" => [],
          "StateMachine" => {},
          "Task"         => {}
        }
      end

      def execution
        @context["Execution"]
      end

      def started?
        execution.key?("StartTime")
      end

      def running?
        started? && !ended?
      end

      def ended?
        execution.key?("EndTime")
      end

      def state
        @context["State"]
      end

      def input
        state["Input"]
      end

      def output
        state["Output"]
      end

      def state_name
        state["Name"]
      end

      def next_state
        state["NextState"]
      end

      def status
        if !started?
          "pending"
        elsif running?
          "running"
        elsif state["Error"]
          "failure"
        else
          "success"
        end
      end

      def start_next_state!(name = state["NextState"], input = state["Output"], init: false)
        if init == true || state_name.nil?
          execution["StartTime"] = Time.now.utc
          input = execution["Input"]
        end
        @context["State"] = {
          "Name"  => name,
          "Input" => input.dup,
          "Guid"  => SecureRandom.uuid
        }

        self
      end

      def end_state!(output, next_state = nil, cause: nil, error: nil)
        state["Output"]      = output
        state["NextState"]   = next_state
        state["Error"]       = error if error
        state["Cause"]       = cause if cause
        execution["EndTime"] = Time.now.utc unless next_state

        self
      end

      def state_history
        @context["StateHistory"]
      end

      def state_machine
        @context["StateMachine"]
      end

      def task
        @context["Task"]
      end

      def [](key)
        @context[key]
      end

      def []=(key, val)
        @context[key] = val
      end

      def dig(*args)
        @context.dig(*args)
      end

      def to_h
        @context
      end
    end
  end
end
