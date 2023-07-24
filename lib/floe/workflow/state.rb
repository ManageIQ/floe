# frozen_string_literal: true

module Floe
  class Workflow
    class State
      include Logging

      class << self
        def build!(workflow, name, payload)
          state_type = payload["Type"]

          begin
            klass = Floe::Workflow::States.const_get(state_type)
          rescue NameError
            raise Floe::InvalidWorkflowError, "Invalid state type: [#{state_type}]"
          end

          klass.new(workflow, name, payload)
        end
      end

      attr_reader :workflow, :comment, :name, :type, :payload

      def initialize(workflow, name, payload)
        @workflow = workflow
        @name     = name
        @payload  = payload
        # All states must define Next or End except for Choice, Succeed, and Fail
        @end      = !!payload["End"]
        @next     = payload["Next"]
        # All states must define a Type
        @type     = payload["Type"]
        # All states may define a Comment
        @comment  = payload["Comment"]
        # All states may define InputPath and OutputPath except for Fail
        @input_path  = Path.new(payload.fetch("InputPath", "$"))
        @output_path = Path.new(payload.fetch("OutputPath", "$"))
      end

      # https://states-language.net/#terminal-state
      # @return [Boolean] true if there is no transition from this state
      def terminal_state?
        @end
      end

      def next_state
        terminal_state? ? nil : @next
      end

      def run!(input)
        input = @input_path.value(context, input) if @input_path
        output = run_input!(input)
        output = @output_path.value(context, output) if @output_path

        [next_state, output]
      end

      def context
        workflow.context
      end

      def status
        "success"
      end
    end
  end
end
