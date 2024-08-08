# frozen_string_literal: true

module Floe
  module ValidationMixin
    def self.included(base)
      base.extend(ClassMethods)
    end

    def parser_error!(comment)
      self.class.parser_error!(name, comment)
    end

    def missing_field_error!(field_name)
      self.class.missing_field_error!(name, field_name)
    end

    def invalid_field_error!(field_name, field_value = nil, comment = nil)
      self.class.invalid_field_error!(name, field_name, field_value, comment)
    end

    def runtime_field_error!(field_name, field_value, comment, floe_error: "States.Runtime")
      raise Floe::ExecutionError.new(self.class.field_error_text(name, field_name, field_value, comment), floe_error)
    end

    def workflow_state?(field_value, workflow)
      workflow.payload["States"] ? workflow.payload["States"].include?(field_value) : true
    end

    def wrap_parser_error(field_name, field_value)
      yield
    rescue ArgumentError, InvalidWorkflowError => error
      invalid_field_error!(field_name, field_value, error.message)
    end

    module ClassMethods
      def parser_error!(name, comment)
        name = name.join(".") if name.kind_of?(Array)
        raise Floe::InvalidWorkflowError, "#{name} #{comment}"
      end

      def missing_field_error!(name, field_name)
        parser_error!(name, "does not have required field \"#{field_name}\"")
      end

      def invalid_field_error!(name, field_name, field_value, comment)
        raise Floe::InvalidWorkflowError, field_error_text(name, field_name, field_value, comment)
      end

      def field_error_text(name, field_name, field_value, comment = nil)
        # instead of displaying a large hash or array, just displaying the word Hash or Array
        field_value = field_value.class if field_value.kind_of?(Hash) || field_value.kind_of?(Array)

        "#{Array(name).join(".")} field \"#{field_name}\"#{" value \"#{field_value}\"" unless field_value.nil?} #{comment}"
      end
    end
  end
end
