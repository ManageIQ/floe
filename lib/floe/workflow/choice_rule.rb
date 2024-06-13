# frozen_string_literal: true

module Floe
  class Workflow
    class ChoiceRule
      class << self
        def build(validator, payload)
          if (sub_payloads = payload["Not"])
            Floe::Workflow::ChoiceRule::Not.new(validator, payload, build_children(validator.for_children, [sub_payloads]))
          elsif (sub_payloads = payload["And"])
            Floe::Workflow::ChoiceRule::And.new(validator, payload, build_children(validator.for_children, sub_payloads))
          elsif (sub_payloads = payload["Or"])
            Floe::Workflow::ChoiceRule::Or.new(validator, payload, build_children(validator.for_children, sub_payloads))
          else
            Floe::Workflow::ChoiceRule::Data.new(validator, payload)
          end
        end

        def build_children(validator, sub_payloads)
          sub_payloads.map { |payload| build(validator, payload) }
        end
      end

      attr_reader :next, :payload, :variable, :children

      def initialize(validator, payload, children = nil)
        @payload   = payload
        @children  = children

        @next     = payload["Next"]
        @variable = payload["Variable"]

        validate_next!(validator)
      end

      def true?(*)
        raise NotImplementedError, "Must be implemented in a subclass"
      end

      private

      def validate_next!(validator)
        if validator.children
          # next is not allowed for lower levels
          validator.reject!("Next", @next)
        else
          # next is required for the top level
          validator.validate_state_ref!("Next", @next)
        end
      end

      def variable_value(context, input)
        Path.value(variable, context, input)
      end
    end
  end
end
