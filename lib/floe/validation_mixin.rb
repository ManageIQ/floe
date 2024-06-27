# frozen_string_literal: true

module Floe
  module ValidationMixin
    def self.included(base)
      base.extend(ClassMethods)
    end

    def path!(field_name, field_value)
      Workflow::Path.new(field_value) if field_value
    rescue Floe::InvalidWorkflowError => err
      error!("requires Path field \"#{field_name}\" #{err.message}")
    end

    def reference_path!(field_name, field_value)
      Workflow::ReferencePath.new(field_value)
    rescue Floe::InvalidWorkflowError => err
      error!("requires ReferencePath field \"#{field_name}\" #{err.message}")
    end

    def payload_template!(_field_name, field_value)
      Workflow::PayloadTemplate.new(field_value) if field_value
    end

    def require_field!(field_name, field_value, type: String)
      error!("requires #{type} field \"#{field_name}\"") if field_value.nil? || (field_value.respond_to?(:empty?) && field_value.empty?)
      error!("requires #{type} field \"#{field_name}\" but got [#{field_value}]") if !field_value.kind_of?(type)

      field_value
    end

    def state_ref!(field_name, field_value, workflow)
      error!("requires field \"#{field_name}\" to be in \"States\" list but got [#{field_value}]") if field_value && !workflow.payload["States"].include?(field_value)

      field_value
    end

    def error!(comment)
      raise Floe::InvalidWorkflowError, "#{full_name.join(".")} #{comment}"
    end

    module ClassMethods
      def error!(full_name, comment)
        raise Floe::InvalidWorkflowError, "#{full_name.join(".")} #{comment}"
      end
    end
  end
end
