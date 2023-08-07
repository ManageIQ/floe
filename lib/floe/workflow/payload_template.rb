# frozen_string_literal: true

module Floe
  class Workflow
    class PayloadTemplate
      def initialize(payload)
        @payload_template = parse_payload(payload)
      end

      def value(context, inputs = {})
        interpolate_value(payload_template, context, inputs)
      end

      private

      attr_reader :payload_template

      def parse_payload(value)
        case value
        when Array  then parse_payload_array(value)
        when Hash   then parse_payload_hash(value)
        when String then parse_payload_string(value)
        else
          value
        end
      end

      def parse_payload_array(value)
        value.map { |val| parse_payload(val) }
      end

      def parse_payload_hash(value)
        value.to_h do |key, val|
          if key.end_with?(".$")
            if value.key?(key.chomp(".$"))
              raise Floe::InvalidWorkflowError, "both #{key} and #{key.chomp(".$")} present"
            end

            [key, parse_payload(val)]
          else
            [key, val]
          end
        end
      end

      def parse_payload_string(value)
        if value.start_with?("$")
          Path.new(value)
        elsif value.match?(/^\w+\.\w+\(.+\)$/)
          IntrinsicFunction.new(value)
        else
          value
        end
      end

      def interpolate_value(value, context, inputs)
        case value
        when Array then interpolate_value_array(value, context, inputs)
        when Hash  then interpolate_value_hash(value, context, inputs)
        when Path, IntrinsicFunction then value.value(context, inputs)
        else
          value
        end
      end

      def interpolate_value_array(value, context, inputs)
        value.map { |val| interpolate_value(val, context, inputs) }
      end

      def interpolate_value_hash(value, context, inputs)
        value.to_h do |key, val|
          if key.end_with?(".$")
            [key.chomp(".$"), interpolate_value(val, context, inputs)]
          else
            [key, val]
          end
        end
      end
    end
  end
end
