# frozen_string_literal: true

module Floe
  class Workflow
    class ChoiceRule
      class << self
        def build(payload)
          if (sub_payloads = payload["Not"])
            Floe::Workflow::ChoiceRule::Not.new(payload, build_children(payload, [sub_payloads]))
          elsif (sub_payloads = payload["And"])
            Floe::Workflow::ChoiceRule::And.new(payload, build_children(payload, sub_payloads))
          elsif (sub_payloads = payload["Or"])
            Floe::Workflow::ChoiceRule::Or.new(payload, build_children(payload, sub_payloads))
          else
            Floe::Workflow::ChoiceRule::Data.new(payload)
          end
        end

        def build_children(parent_payload, sub_payloads)
          sub_payloads.map { |payload| build(parent_payload.for_children(payload)) }
        end
      end

      attr_reader :next, :payload, :variable, :children

      def initialize(payload, children = nil)
        @payload   = payload
        @children  = children

        # Or rules have children and no Variable
        unless children
          @variable = payload.path!("Variable")
        end

        if payload.children
          # next is not allowed for lower levels
          # TODO: fix syntax of this
          payload.reject!("Next")
        else
          # next is required for the top level
          @next = payload.state_ref!("Next")
        end
      end

      def true?(*)
        raise NotImplementedError, "Must be implemented in a subclass"
      end

      private

      def variable_value(context, input)
        variable.value(context, input)
      end
    end
  end
end
