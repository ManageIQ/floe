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

      attr_reader :next, :payload, :variable, :children, :full_name

      def initialize(workflow, full_name, payload, children = nil)
        @full_name = full_name
        @payload   = payload
        @children  = children

        # only valid when !is_child? but reading for validation later
        @next      = payload["Next"]
        @variable = path!("Variable", payload["Variable"])

        validate_rule!(workflow, children)
      end

      def true?(*)
        raise NotImplementedError, "Must be implemented in a subclass"
      end

      private

      def validate_rule!(workflow, children)
        error!("requires Path field \"Variable\"") if !@variable && !children
        error!("does not recognize field \"Variable\"") if @variable && children

        error!("requires field \"Next\"") if @next.nil? && !is_child?
        error!("requires field \"Next\" to be in \"States\" list but got [#{@next}]") if @next && !workflow.payload["States"].key?(@next)
        error!("does not recognize field \"Next\"") if @next && is_child?
      end

      def is_child?
        %w[And Or Not].include?(full_name[-3])
      end

      def variable_value(context, input)
        variable.value(context, input)
      end
    end
  end
end
