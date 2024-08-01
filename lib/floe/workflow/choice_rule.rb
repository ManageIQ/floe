# frozen_string_literal: true

module Floe
  class Workflow
    class ChoiceRule
      include ValidationMixin

      class << self
        def build(workflow, name, payload)
          if (sub_payloads = payload["Not"])
            name += ["Not"]
            Floe::Workflow::ChoiceRule::Not.new(workflow, name, payload, build_children(workflow, name, [sub_payloads]))
          elsif (sub_payloads = payload["And"])
            name += ["And"]
            Floe::Workflow::ChoiceRule::And.new(workflow, name, payload, build_children(workflow, name, sub_payloads))
          elsif (sub_payloads = payload["Or"])
            name += ["Or"]
            Floe::Workflow::ChoiceRule::Or.new(workflow, name, payload, build_children(workflow, name, sub_payloads))
          else
            name += ["Data"]
            Floe::Workflow::ChoiceRule::Data.new(workflow, name, payload)
          end
        end

        def build_children(workflow, name, sub_payloads)
          sub_payloads.map.with_index { |payload, i| build(workflow, name + [i.to_s], payload) }
        end
      end

      attr_reader :next, :payload, :children, :name

      def initialize(workflow, name, payload, children = nil)
        @name      = name
        @payload   = payload
        @children  = children
        @next      = payload["Next"]

        validate_rule!(workflow)
      end

      def true?(*)
        raise NotImplementedError, "Must be implemented in a subclass"
      end

      private

      def validate_rule!(workflow)
        if is_child?
          # non-top level nodes don't allow a next
          invalid_field_error!("Next", @next, "not allowed in a child rule") if @next
        elsif !@next
          # top level nodes require a next
          missing_field_error!("Next")
        elsif !workflow_state?(@next, workflow)
          # top level nodes require a next field that is found
          invalid_field_error!("Next", @next, "is not found in \"States\"")
        end
      end

      # returns true if this is a child rule underneath an And/Or/Not
      def is_child? # rubocop:disable Naming/PredicateName
        !(%w[And Or Not] & name[0..-2]).empty?
      end
    end
  end
end
