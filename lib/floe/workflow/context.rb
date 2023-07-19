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
          "ActiveStates" => {},
          # completed states
          "States"       => [],
          "StateMachine" => {},
          "Task"         => {}
        }
      end

      def execution
        @context["Execution"]
      end

      # # @returns [Hash] Currently Active State
      # def state
      #   @context["State"]
      # end

      # def state=(val)
      #   @context["State"] = val
      # end

      # @returns [Array<Hash>] List of current states
      def active_states=(val)
        @context["ActiveStates"] = Array.wrap(val)
      end

      # @returns [Array<Hash>] Active States
      def active_states(val)
        @context["ActiveStates"]
      end

      def last_activ_state
        @context["ActiveStates"].last
      end

      # @returns [Array<Hash>] Completed States
      def states
        @context["States"]
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
