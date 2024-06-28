# frozen_string_literal: true

module Floe
  module ValidationMixin
    class ValidationField
      # NOTE: default only used for number, path, reference_path, payload_template
      attr_accessor :attribute_name, :field_name, :type, :default, :block

      def initialize(attribute_name, field_name, type, default: nil, block: nil)
        default ||= false if type == :boolean

        @attribute_name = attribute_name
        @field_name     = field_name
        @type           = type
        @block          = block
        @default        = default
      end

      def klass
        {:string => String, :number => Numeric, :list => Array, :hash => Hash, :timestamp => Date, :state_ref => String}[type] || type
      end

      def set_value(record, payload, workflow)
        field_value = payload[field_name] || default
        # could go with string! or field! -- generic seems to work for now
        converted_value =
          case type
          when :boolean          then record.boolean!(field_name, field_value)
          when :string           then record.string!(field_name, field_value)
          when :number           then record.number!(field_name, field_value)
          when :list             then record.list!(field_name, field_value, workflow, &block)
          when :hash             then record.hash!(field_name, field_value, workflow, &block)
          when :timestamp        then record.timestamp!(field_name, field_value || default)
          when :state_ref        then record.state_ref!(field_name, field_value, workflow)
          when :path             then record.path!(field_name, field_value)
          when :reference_path   then record.reference_path!(field_name, field_value)
          when :payload_template then record.payload_template!(field_name, field_value)
          when :raw              then field_value
          else
            raise "what is a #{type}"
          end
        record.instance_variable_set(:"@#{attribute_name}", converted_value)
      end

      def current_value(record)
        record.public_send(attribute_name)
      end

      def value?(record)
        field_value = current_value(record)
        field_value && !(field_value.respond_to?(:empty?) && field_value.empty?)
      end
    end

    # validation dsl
    class ValidationHandler
      attr_accessor :klass

      def initialize(klass)
        @klass = klass
      end

      def field(type, field_name, attribute_name: nil, required: false, default: nil, &block)
        # snake case the field
        attribute_name ||= field_name.gsub(/([a-z\d])([A-Z])/, '\1_\2').downcase.to_sym

        klass.attr_accessor attribute_name

        klass.validation_fields = klass.validation_fields.merge(field_name => ValidationField.new(attribute_name, field_name, type, :default => default, :block => block))
        require_set(field_name) if required
      end

      def require_set(*field_names)
        invalid_fields = field_names.reject { |field_name| klass.validation_fields.key?(field_name) }
        raise "unknown require_set fields: #{invalid_fields.join(", ")}" unless invalid_fields.empty?

        klass.validation_set += [field_names]
      end

      # TODO: change from hash to a non-reserved word
      def hash_list(...)
        field(:hash, ...)
      end

      # TODO: verify type
      def method_missing(type, ...)
        field(type, ...)
      end

      # TODO: verify type
      def respond_to_missing?(_type, *)
        true
      end
    end

    def self.included(base)
      base.extend(BasicClassAttribute)
      base.basic_class_attribute(:validation_fields, :default => {})
      base.basic_class_attribute(:validation_set, :default => [])

      base.extend(ClassMethods)
    end

    # validation dsl
    def load_fields(payload, workflow)
      self.class.validation_fields.each_value do |vf|
        vf.set_value(self, payload, workflow)
      end

      self.class.validation_set.each do |field_name_list|
        require_one_alt!(field_name_list)
      end
    end

    def string!(field_name, field_value)
      field!(field_name, field_value, :type => String)
    end

    def boolean!(field_name, field_value)
      field_value ||= false

      error!("requires field \"#{field_name}\" to be a Boolean but got [#{field_value}]") unless [true, false].include?(field_value)

      field_value
    end

    def number!(field_name, field_value)
      field!(field_name, field_value, :type => Numeric)
    end

    def list!(field_name, field_value, workflow = nil)
      param = field!(field_name, field_value, :type => Array)
      return param.to_a if param.nil? || !block_given?

      param.each_with_index.map do |child_payload, i|
        yield workflow, full_name + [field_name, i.to_s], child_payload
      end
    end

    def hash!(field_name, field_value, workflow = nil)
      param = field!(field_name, field_value, :type => Hash)
      return param if param.nil? || !block_given?

      param.map do |child_name, child_payload|
        yield workflow, full_name + [field_name, child_name], child_payload
      end
    end

    def timestamp!(field_name, field_value)
      require "date"
      DateTime.rfc3339(field_value) if field_value

      field_value
    rescue TypeError, Date::Error
      error!("requires field \"#{field_name}\" to be a Date but got [#{field_value}]")
    end

    def state_ref!(field_name, field_value, workflow)
      error!("requires field \"#{field_name}\" to be in \"States\" list but got [#{field_value}]") if field_value && !state?(field_value, workflow)

      field_value
    end

    def path!(field_name, field_value)
      Workflow::Path.new(field_value) if field_value
    rescue Floe::InvalidWorkflowError => err
      error!("requires field \"#{field_name}\" #{err.message}")
    end

    def reference_path!(field_name, field_value)
      Workflow::ReferencePath.new(field_value)
    rescue Floe::InvalidWorkflowError => err
      error!("requires field \"#{field_name}\" #{err.message}")
    end

    def payload_template!(_field_name, field_value)
      Workflow::PayloadTemplate.new(field_value) if field_value
    end

    # this ensures one and only 1 of the listed fields are present
    def require_fields!(field_values)
      # NOTE: intentionally using field_value and not field_value.nil?
      #       false will act like it is not defined
      present_fields = field_values.filter_map do |name, value|
        name unless !value || (value.respond_to?(:empty?) && value.empty?)
      end

      case present_fields.count
      when 0
        error!("requires #{"one " if field_values.size > 1}field \"#{field_values.keys.join(", ")}\"")
      when 1
        nil
      else
        error!("requires only one field: #{present_fields.join(", ")}")
      end
    end

    def require_one_alt!(field_list)
      # NOTE: intentionally using field_value and not field_value.nil?
      #       false will act like it is not defined
      present_fields = field_list.select do |field_name|
        self.class.validation_fields[field_name].value?(self)
      end

      if present_fields.empty?
        error!("requires #{"one " if field_list.size > 1}field \"#{field_list.join(", ")}\"")
      elsif present_fields.size > 1
        error!("requires only one field: #{present_fields.join(", ")}")
      end
    end

    def field!(field_name, field_value, type: String)
      type_str = type.to_s.split('::').last

      error!("requires #{type_str} field \"#{field_name}\" but got #{field_value.class}") if !field_value.nil? && !field_value.kind_of?(type)

      field_value
    end

    # errors

    def reject_field!(field_name, field_value)
      error!("does not recognize field \"#{field_name}\"") if field_value
    end

    def error!(comment)
      raise Floe::InvalidWorkflowError, "#{full_name.empty? ? "Workflow" : full_name.join(".")} #{comment}"
    end

    private

    # Yes, it is an issue if there are no states to search in.
    # This suppresses that error assuming that the more important error (there are no states) be present
    def state?(field_value, workflow)
      workflow.payload["States"] ? workflow.payload["States"].include?(field_value) : true
    end

    module ClassMethods
      def fields(&block)
        ValidationHandler.new(self).instance_eval(&block)
      end

      def error!(full_name, comment)
        raise Floe::InvalidWorkflowError, "#{full_name.join(".")} #{comment}"
      end
    end
  end
end
