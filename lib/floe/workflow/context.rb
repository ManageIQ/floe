# frozen_string_literal: true

module Floe
  class Workflow
    class Context
      # @param context [Json|Hash] (default, create another with input and execution params)
      # @param input [Hash] (default: {})
      def initialize(context = nil, input: {})
        context = JSON.parse(context) if context.kind_of?(String)
        input = JSON.parse(input) if input.kind_of?(String)

        @context = context || {}
        self["Execution"]          ||= {}
        self["Execution"]["Input"] ||= input
        self["State"]              ||= {}
        self["StateHistory"]       ||= []
        self["StateMachine"]       ||= {}
        self["Task"]               ||= {}
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

      def output=(val)
        state["Output"] = val
      end

      def state_name
        state["Name"]
      end

      def next_state
        state["NextState"]
      end

      def next_state=(val)
        state["NextState"] = val
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

      def success?
        status == "success"
      end

      def state=(val)
        @context["State"] = val
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
