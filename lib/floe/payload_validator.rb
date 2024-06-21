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
    # @attr_reader [Array<String>] fields that have been accessed at this level
    #   Fields in the payload that have not been accessed are assumed to be erronious
    attr_reader :referenced

    def initialize(payload, state_names = [], state_name = nil, rule: nil, children: nil)
      @payload     = payload
      @referenced  = []
      @state_names = state_names
      @state_name  = state_name
      @rule        = rule
      @children    = children
    end

    def keys
      payload.keys
    end

    def [](key)
      referenced << key
      payload[key]
    end

    def string!(field_name, required: true)
      field_value = self[field_name]

      if !field_value.nil? && !field_value.kind_of?(String)
        raise Floe::InvalidWorkflowError, "#{src_reference} requires field \"#{field_name}\" to be a String but got [#{field_value}]"
      end

      if required && (field_value.nil? || field_value.empty?)
        raise Floe::InvalidWorkflowError, "#{src_reference} requires field \"#{field_name}\""
      end

      field_value
    end

    def boolean!(field_name)
      field_value = self[field_name] || false
      raise Floe::InvalidWorkflowError, "#{src_reference} requires field \"#{field_name}\" to be a Boolean but got [#{field_value}]" unless [true, false].include?(field_value)

      field_value
    end

    def number!(field_name)
      field_value = self[field_name]

      return field_value if field_value.nil? || field_value.kind_of?(Numeric)

      raise Floe::InvalidWorkflowError, "#{src_reference} requires field \"#{field_name}\" to be a Number but got [#{field_value}]"
    end

    def timestamp!(field_name)
      require "date"
      field_value = self[field_name]

      DateTime.rfc3339(field_value) if field_value

      field_value
    rescue TypeError, Date::Error
      raise Floe::InvalidWorkflowError, "#{src_reference} requires field \"#{field_name}\" to be a Date but got [#{field_value}]"
    end

    def state_ref!(field_name, required: true)
      field_value = self[field_name]

      raise Floe::InvalidWorkflowError, "#{src_reference} requires field \"#{field_name}\"" if field_value.nil? && required
      raise Floe::InvalidWorkflowError, "#{src_reference} requires field \"#{field_name}\" to be in \"States\" list but got [#{field_value}]" if field_value && !state?(field_value)

      field_value
    end

    def list!(field_name, klass: Array, required: true)
      field_value = self[field_name]

      return klass.new if field_value.nil? && !required
      return field_value if field_value.kind_of?(klass) && (!required || !field_value.empty?)

      raise Floe::InvalidWorkflowError, "#{src_reference} requires non-empty #{klass.name} field \"#{field_name}\""
    end

    def path!(field_name, default: :required)
      field_value = self[field_name] || default

      raise Floe::InvalidWorkflowError, "#{src_reference} requires Path field \"#{field_name}\" to exist" if field_value == :required && default == :required

      begin
        Workflow::Path.new(field_value) if field_value
      rescue Floe::InvalidWorkflowError => err
        error!("requires Path field \"#{field_name}\" #{err.message}")
      end
    end

    def reference_path!(field_name, default: "$")
      field_value = self[field_name] || default

      begin
        Workflow::ReferencePath.new(field_value)
      rescue Floe::InvalidWorkflowError => err
        error!("requires ReferencePath field \"#{field_name}\" #{err.message}")
      end
    end

    def payload_template!(field_name, default: nil)
      field_value = self[field_name] || default
      Workflow::PayloadTemplate.new(field_value) if field_value
    end

    def error!(comment)
      raise Floe::InvalidWorkflowError, "#{src_reference} #{comment}"
    end

    # payload methods

    def no_unreferenced_fields!
      unreferenced = keys - referenced
      raise Floe::InvalidWorkflowError, "#{src_reference} does not recognize fields #{unreferenced.join(", ")}" unless unreferenced.empty?
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
