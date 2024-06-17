# frozen_string_literal: true

module Floe
  class PayloadValidator
    # @attr_reader [Array<String>] state_names list of valid state names
    attr_accessor :state_names
    # @attr_reader [String] state_name currently processed state. nil for workflow.
    attr_reader :state_name
    # @attr_reader [String] rule currently processed rule. e.g.: "Choice"
    attr_reader :rule
    # @attr_reader [Boolean] children. true when processing "Choice" sub children (level 2+)
    attr_reader :children
    # @attr_reader [Hash] data that is currently being parsed.
    attr_reader :payload

    def initialize(payload, state_names = [], state_name = nil, rule: nil, children: nil)
      @payload     = payload
      @state_names = state_names
      @state_name  = state_name
      @rule        = rule
      @children    = children
    end

    def keys
      payload.keys
    end

    def [](key)
      payload[key]
    end

    # @param [Class] klass the class of the field
    def field!(field_name, klass: String, default: :required)
      field_value = self[field_name]

      if default == :required && (field_value.nil? || field_value.empty?)
        raise Floe::InvalidWorkflowError, "#{src_reference} requires field \"#{field_name}\""
      end

      field_value ||= default

      if !field_value.nil? && !field_value.kind_of?(klass)
        raise Floe::InvalidWorkflowError, "#{src_reference} requires #{klass} field \"#{field_name}\" got [#{field_value}]"
      end

      field_value
    end

    def boolean!(field_name, default: :required, klass: "Boolean")
      field_value = self[field_name] || default
      raise Floe::InvalidWorkflowError, "#{src_reference} requires boolean field \"#{field_name}\"" if !payload.key?(field_name) && default == :required
      raise Floe::InvalidWorkflowError, "#{src_reference} requires #{klass} field \"#{field_name}\" got [#{field_value}]" unless [true, false].include?(field_value)

      field_value
    end

    def state_ref!(field_name, optional: false)
      field_value = self[field_name]

      raise Floe::InvalidWorkflowError, "#{src_reference} requires field \"#{field_name}\"" if field_value.nil? && !optional
      raise Floe::InvalidWorkflowError, "#{src_reference} requires field \"#{field_name}\" to be in \"States\" list but got [#{field_value}]" if field_value && !state?(field_value)

      field_value
    end

    def list!(field_name, klass: Array, default: :required)
      field_value = self[field_name]

      return field_value || default if default != :required && field_value.nil?
      return field_value if field_value.kind_of?(klass) && !field_value.empty?

      raise Floe::InvalidWorkflowError, "#{src_reference} requires non-empty #{klass.name} field \"#{field_name}\""
    end

    def path!(field_name, default: :required)
      field_value = self[field_name]

      return if field_value.nil? && default.nil?
      raise Floe::InvalidWorkflowError, "#{src_reference} requires Path field \"#{field_name}\" to exist" if field_value.nil? && default == :required

      field_value ||= default

      begin
        Workflow::Path.new(field_value)
      rescue Floe::InvalidWorkflowError => err
        bad_type!(field_name, field_value, err.message, :type => "Path")
      end
    end

    def reference_path!(field_name, default: :required)
      field_value = self[field_name]
      raise Floe::InvalidWorkflowError, "#{src_reference} requires ReferencePath field \"#{field_name}\" to exist" if field_value.nil? && default == :required

      field_value ||= default

      begin
        Workflow::ReferencePath.new(field_value)
      rescue Floe::InvalidWorkflowError => err
        bad_type!(field_name, field_value, err.message, :type => "ReferencePath")
      end
    end

    def payload_template!(field_name, default: nil)
      field_value = self[field_name] || default
      Workflow::PayloadTemplate.new(field_value) if field_value
    end

    # Similar to validate_field! but much of the logic is external
    def bad_type!(field_name, field_value, comment = nil, type:)
      comment ||= "got [#{field_value}]"
      raise Floe::InvalidWorkflowError, "#{src_reference} requires #{type} field \"#{field_name}\"#{" " if comment}#{comment}"
    end

    # an unexpected field was found
    def reject!(field_name, comment = nil)
      field_value = self[field_name]
      raise Floe::InvalidWorkflowError, "#{src_reference} does not allow field \"#{field_name}\" with value [#{field_value}]#{" " if comment}#{comment}" if field_value
    end

    def with_states(state_names)
      self.class.new(payload, state_names)
    end

    def for_state(name, new_payload = nil)
      self.class.new(new_payload, state_names, name)
    end

    def for_rule(rule, new_payload)
      self.class.new(new_payload, state_names, state_name, :rule => rule)
    end

    def for_children(new_payload)
      self.class.new(new_payload, state_names, state_name, :rule => rule, :children => true)
    end

    private

    def state?(name)
      @state_names.include?(name)
    end

    def src_reference
      "#{state_name ? "State [#{state_name}]" : "Workflow"}#{" " if rule}#{rule}#{" child rule" if children}"
    end
  end
end
