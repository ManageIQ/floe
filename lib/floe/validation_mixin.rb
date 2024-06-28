# frozen_string_literal: true

module Floe
  module ValidationMixin
    def self.included(base)
      base.extend(ClassMethods)
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
      def error!(full_name, comment)
        raise Floe::InvalidWorkflowError, "#{full_name.join(".")} #{comment}"
      end
    end
  end
end
