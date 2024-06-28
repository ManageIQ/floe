# frozen_string_literal: true

module Floe
  module ValidationMixin
    def self.included(base)
      base.extend(ClassMethods)
    end

    def parser_error!(comment)
      self.class.parser_error!(full_name_string, comment)
    end

    def parser_missing_field!(field_name)
      self.class.parser_missing_field!(full_name_string, field_name)
    end

    def parser_invalid_field!(field_name, field_value = nil, comment = nil)
      self.class.parser_invalid_field!(full_name_string, field_name, field_value, comment)
    end

    def workflow_state?(field_value, workflow)
      workflow.payload["States"] ? workflow.payload["States"].include?(field_value) : true
    end

    private

    def full_name_string
      full_name.join(".")
    end

    module ClassMethods
      def parser_error!(full_name, comment)
        full_name = full_name.join(".") if full_name.kind_of?(Array)
        raise Floe::InvalidWorkflowError, "#{full_name} #{comment}"
      end

      def parser_missing_field!(full_name, field_name)
        parser_error!(full_name, "does not have required field \"#{field_name}\"")
      end

      def parser_invalid_field!(full_name, field_name, field_value, comment)
        field_value = field_value.class if field_value.kind_of?(Hash) || field_value.kind_of?(Array)

        parser_error!(full_name, "field \"#{field_name}\"#{" value \"#{field_value}\"" unless field_value.nil?} #{comment}")
      end
    end
  end
end
