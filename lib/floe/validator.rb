# frozen_string_literal: true

module Floe
  class Validator
    # @attr_reader [Array<String>] state_names list of valid state names
    attr_accessor :state_names
    # @attr_reader [String] state_name currently processed state. nil for workflow.
    attr_reader :state_name
    # @attr_reader [String] rule currently processed rule. e.g.: "Choice"
    attr_reader :rule
    # @attr_reader [Boolean] children. true when processing a choice sub children (level 2+)
    attr_reader :children

    def initialize(state_names = [], state_name = nil, rule: nil, children: nil)
      @state_names = state_names
      @state_name  = state_name
      @rule        = rule
      @children    = children
    end

    # @param [String|Class] klass typically passing a klass, but if the types are complicated, pass a string description (used by ChoiceRule)
    def validate_field!(field_name, field_value, klass: String, force: false)
      raise Floe::InvalidWorkflowError, "#{src_reference} requires field \"#{field_name}\"" if field_value.nil?

      return field_value if (klass.kind_of?(String) || (field_value.kind_of?(klass) && !field_value.empty?)) && !force

      raise Floe::InvalidWorkflowError, "#{src_reference} requires #{klass} field \"#{field_name}\" got [#{field_value}]"
    end

    def validate_state_ref!(field_name, field_value, optional: false)
      raise Floe::InvalidWorkflowError, "#{src_reference} requires field \"#{field_name}\"" if field_value.nil? && !optional
      raise Floe::InvalidWorkflowError, "#{src_reference} requires field \"#{field_name}\" to be in \"States\" list but got [#{field_value}]" if field_value && !state?(field_value)

      field_value
    end

    def validate_list!(field_name, field_value, klass: Array, optional: false)
      return field_value if optional && field_value.nil?
      return field_value if field_value.kind_of?(klass) && !field_value.empty?

      raise Floe::InvalidWorkflowError, "#{src_reference} requires non-empty #{klass.name} field \"#{field_name}\""
    end

    def reject!(field_name, field_value)
      raise Floe::InvalidWorkflowError, "#{src_reference} does not allow field \"#{field_name}\" with value [#{field_value}]" if field_value
    end

    def for_state(name, rule: nil)
      self.class.new(state_names, name, :rule => rule)
    end

    def for_children
      self.class.new(state_names, state_name, :rule => rule, :children => true)
    end

    private

    def state?(name)
      @state_names.include?(name)
    end

    def src_reference
      "#{state_name ? "State [#{state_name}]" : "Workflow"}#{" " if rule}#{rule}#{" child" if children}"
    end
  end
end
