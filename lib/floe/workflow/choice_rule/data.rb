# frozen_string_literal: true

module Floe
  class Workflow
    class ChoiceRule
      class Data < Floe::Workflow::ChoiceRule
        TYPES      = {"String" => :is_string?, "Numeric" => :is_numeric?, "Boolean" => :is_boolean?, "Timestamp" => :is_timestamp?, "Present" => :is_present?, "Null" => :is_null?}.freeze
        COMPARES   = ["Equals", "LessThan", "GreaterThan", "LessThanEquals", "GreaterThanEquals", "Matches"].freeze
        # e.g.: (Is)(String), (Is)(Present)
        TYPE_CHECK = /^(Is)(#{TYPES.keys.join("|")})$/.freeze
        # e.g.: (String)(LessThan)(Path), (Numeric)(GreaterThanEquals)()
        OPERATION  = /^(#{(TYPES.keys - %w[Null Present]).join("|")})(#{COMPARES.join("|")})(Path)?$/.freeze

        attr_reader :variable, :compare_key, :type, :value, :path

        def initialize(_workflow, _name, payload)
          super

          @variable = parse_path("Variable", payload)
          parse_compare_key
          @value = parse_compare_value
        end

        def true?(context, input)
          return presence_check(context, input) if compare_key == "IsPresent"

          lhs = variable_value(context, input)
          rhs = compare_value(context, input)

          case compare_key
          when "IsNull" then is_null?(lhs, rhs)
          when "IsNumeric" then is_numeric?(lhs, rhs)
          when "IsString" then is_string?(lhs, rhs)
          when "IsBoolean" then is_boolean?(lhs, rhs)
          when "IsTimestamp" then is_timestamp?(lhs, rhs)
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

        # rubocop:disable Naming/PredicateName
        # rubocop:disable Style/OptionalBooleanParameter
        def is_null?(value, ret_value = true)
          value.nil? == ret_value
        end

        def is_present?(value, ret_value = true)
          !value.nil? == ret_value
        end

        def is_numeric?(value, ret_value = true)
          value.kind_of?(Numeric) == ret_value
        end

        def is_string?(value, ret_value = true)
          value.kind_of?(String) == ret_value
        end

        def is_boolean?(value, ret_value = true)
          [true, false].include?(value) == ret_value
        end

        def is_timestamp?(value, ret_value = true)
          require "date"

          DateTime.rfc3339(value)
          ret_value
        rescue TypeError, Date::Error
          !ret_value
        end
        # rubocop:enable Naming/PredicateName
        # rubocop:enable Style/OptionalBooleanParameter

        def variable_value(context, input)
          fetch_path("Variable", variable, context, input)
        end

        def compare_value(context, input)
          path ? fetch_path(compare_key, value, context, input) : value
        end

        def fetch_path(field_name, field_path, context, input)
          ret_value = field_path.value(context, input)
          runtime_field_error!(field_name, field_path.to_s, "must point to a #{type}") if type && !correct_type?(ret_value)
          ret_value
        end

        def parse_compare_key
          @compare_key = payload.keys.detect { |key| key.match?(TYPE_CHECK) || key.match?(OPERATION) }
          parser_error!("requires a compare key") unless compare_key

          @type, _operator, @path = OPERATION.match(compare_key)&.captures
          # TYPE_CHECK doesn't match this regex, so @path = @type = nil
          # @path.nil? means this the compare_value will always be a static value (true or false)
          # @type.nil? means we won't type check the variable or compare value
        end

        def parse_compare_value
          if @path
            parse_path(@compare_key, payload)
          else
            parse_value(@compare_key, payload)
          end
        end

        def correct_type?(val)
          send(TYPES[type || "Boolean"], val)
        end

        def parse_path(field_name, payload)
          value = payload[field_name]
          missing_field_error!(field_name) unless value
          wrap_parser_error(field_name, value) { Path.new(value) }
        end

        def parse_value(field_name, payload)
          value = payload[field_name]
          invalid_field_error!(field_name, value, "required to be a #{type || "Boolean"}") unless correct_type?(value)
          value
        end
      end
    end
  end
end
