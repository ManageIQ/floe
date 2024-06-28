# frozen_string_literal: true

module Floe
  class Workflow
    class ChoiceRule
      include ValidationMixin

      class << self
        def build(workflow, full_name, payload)
          if (sub_payloads = payload["Not"])
            name = full_name + ["Not"]
            Floe::Workflow::ChoiceRule::Not.new(workflow, name, payload, build_children(workflow, name, [sub_payloads]))
          elsif (sub_payloads = payload["And"])
            name = full_name + ["And"]
            Floe::Workflow::ChoiceRule::And.new(workflow, name, payload, build_children(workflow, name, sub_payloads))
          elsif (sub_payloads = payload["Or"])
            name = full_name + ["Or"]
            Floe::Workflow::ChoiceRule::Or.new(workflow, name, payload, build_children(workflow, name, sub_payloads))
          else
            name = full_name + ["Data"]
            Floe::Workflow::ChoiceRule::Data.new(workflow, name, payload)
          end
        end

        def build_children(workflow, full_name, sub_payloads)
          sub_payloads.each_with_index.map { |payload, i| build(workflow, full_name + [i.to_s], payload) }
        end
      end

      attr_reader :children, :full_name

      fields do
        state_ref "Next"
        path      "Variable"
      end

      def initialize(workflow, full_name, payload, children = nil)
        @full_name = full_name
        @children  = children

        load_fields(payload, workflow)
        validate_rule!(children)
      end

      def true?(*)
        raise NotImplementedError, "Must be implemented in a subclass"
      end

      private

      def validate_rule!(children)
        if children
          reject_field!("Variable", @variable)
        else
          require_fields!("Variable" => @variable)
        end

        if is_child?
          reject_field!("Next", @next)
        else
          require_fields!("Next" => @next)
        end
      end

      def is_child? # rubocop:disable Naming/PredicateName
        %w[And Or Not].include?(full_name[-3])
      end

      def variable_value(context, input)
        variable.value(context, input)
      end
    end
  end
end
