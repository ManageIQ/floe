# frozen_string_literal: true

module Floe
  class Workflow
    class ChoiceRule
      class Data < Floe::Workflow::ChoiceRule
        COMPARE_KEYS = %w[IsNull IsPresent IsNumeric IsString IsBoolean IsTimestamp String Numeric Boolean Timestamp].freeze

        attr_reader :variable, :compare_key, :value, :path

        def initialize(_workflow, _name, payload)
          super

          @variable = parse_path("Variable", payload)
          parse_compare_key
          @value = path ? parse_path(compare_key, payload) : payload[compare_key]
        end

        def true?(context, input)
          return presence_check(context, input) if compare_key == "IsPresent"

          lhs = variable_value(context, input)
          rhs = compare_value(context, input)

          case compare_key
          when "IsNull" then is_null?(lhs)
          when "IsNumeric" then is_numeric?(lhs)
          when "IsString" then is_string?(lhs)
          when "IsBoolean" then is_boolean?(lhs)
          when "IsTimestamp" then is_timestamp?(lhs)
          when "StringEquals", "StringEqualsPath",
               "NumericEquals", "NumericEqualsPath",
               "BooleanEquals", "BooleanEqualsPath",
               "TimestampEquals", "TimestampEqualsPath"
            lhs == rhs
          when "StringLessThan", "StringLessThanPath",
               "NumericLessThan", "NumericLessThanPath",
               "TimestampLessThan", "TimestampLessThanPath"
            lhs < rhs
          when "StringGreaterThan", "StringGreaterThanPath",
               "NumericGreaterThan", "NumericGreaterThanPath",
               "TimestampGreaterThan", "TimestampGreaterThanPath"
            lhs > rhs
          when "StringLessThanEquals", "StringLessThanEqualsPath",
               "NumericLessThanEquals", "NumericLessThanEqualsPath",
               "TimestampLessThanEquals", "TimestampLessThanEqualsPath"
            lhs <= rhs
          when "StringGreaterThanEquals", "StringGreaterThanEqualsPath",
               "NumericGreaterThanEquals", "NumericGreaterThanEqualsPath",
               "TimestampGreaterThanEquals", "TimestampGreaterThanEqualsPath"
            lhs >= rhs
          when "StringMatches"
            lhs.match?(Regexp.escape(rhs).gsub('\*', '.*?'))
          else
            raise Floe::InvalidWorkflowError, "Invalid choice [#{compare_key}]"
          end
        end

        private

        def presence_check(context, input)
          # Get the right hand side for {"Variable": "$.foo", "IsPresent": true} i.e.: true
          # If true  then return true when present.
          # If false then return true when not present.
          rhs = compare_value(context, input)
          # Don't need the variable_value, just need to see if the path finds the value.
          variable_value(context, input)

          # The variable_value is present
          # If rhs is true, then presence check was successful, return true.
          rhs
        rescue Floe::PathError
          # variable_value is not present. (the path lookup threw an error)
          # If rhs is false, then it successfully wasn't present, return true.
          !rhs
        end

        def is_null?(value) # rubocop:disable Naming/PredicateName
          value.nil?
        end

        def is_present?(value) # rubocop:disable Naming/PredicateName
          !value.nil?
        end

        def is_numeric?(value) # rubocop:disable Naming/PredicateName
          value.kind_of?(Integer) || value.kind_of?(Float)
        end

        def is_string?(value) # rubocop:disable Naming/PredicateName
          value.kind_of?(String)
        end

        def is_boolean?(value) # rubocop:disable Naming/PredicateName
          [true, false].include?(value)
        end

        def is_timestamp?(value) # rubocop:disable Naming/PredicateName
          require "date"

          DateTime.rfc3339(value)
          true
        rescue TypeError, Date::Error
          false
        end

        def variable_value(context, input)
          variable.value(context, input)
        end

        def compare_value(context, input)
          path ? value.value(context, input) : value
        end

        def parse_compare_key
          @compare_key = payload.keys.detect { |key| key.match?(/^(#{COMPARE_KEYS.join("|")})/) }
          parser_error!("requires a compare key") unless compare_key

          @path = compare_key.end_with?("Path")
        end

        def parse_path(field_name, payload)
          value = payload[field_name]
          missing_field_error!(field_name) unless value
          wrap_parser_error(field_name, value) { Path.new(value) }
        end
      end
    end
  end
end
