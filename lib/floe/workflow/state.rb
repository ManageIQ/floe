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
        @end      = !!payload["End"]
        @type     = payload["Type"]
        @comment  = payload["Comment"]
      end

      def end?
        @end
      end

      def context
        workflow.context
      end

      def status
        end? ? "success" : "running"
      end

      def run!(input)
        logger.info("Running state: [#{name}] with input [#{input}]")

        input = input_path.value(context, input)

        output     = block_given? ? yield(input) : input
        next_state = workflow.states_by_name[@next] unless end?

        output ||= input
        output   = output_path&.value(context, output)

        logger.info("Running state: [#{name}] with input [#{input}]...Complete - next state: [#{next_state&.name}] output: [#{output}]")

        [next_state, output]
      end
    end
  end
end
