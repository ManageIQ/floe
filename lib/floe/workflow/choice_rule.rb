# frozen_string_literal: true

module Floe
  class Workflow
    class ChoiceRule
      class << self
        def build(full_name, payload)
          if (sub_payloads = payload["Not"])
            name = full_name + ["Not"]
            Floe::Workflow::ChoiceRule::Not.new(name, payload, build_children(name, [sub_payloads]))
          elsif (sub_payloads = payload["And"])
            name = full_name + ["And"]
            Floe::Workflow::ChoiceRule::And.new(name, payload, build_children(name, sub_payloads))
          elsif (sub_payloads = payload["Or"])
            name = full_name + ["Or"]
            Floe::Workflow::ChoiceRule::Or.new(name, payload, build_children(name, sub_payloads))
          else
            name = full_name + ["Data"]
            Floe::Workflow::ChoiceRule::Data.new(name, payload)
          end
        end

        def build_children(full_name, sub_payloads)
          sub_payloads.each_with_index.map { |payload, i| build(full_name + [i.to_s], payload) }
        end
      end

      attr_reader :next, :payload, :variable, :children, :full_name

      def initialize(full_name, payload, children = nil)
        @full_name = full_name
        @payload   = payload
        @children  = children

        @next     = payload["Next"]
        @variable = payload["Variable"]
      end

      def true?(*)
        raise NotImplementedError, "Must be implemented in a subclass"
      end

      private

      def variable_value(context, input)
        Path.value(variable, context, input)
      end
    end
  end
end
