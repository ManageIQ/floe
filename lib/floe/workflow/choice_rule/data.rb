# frozen_string_literal: true

module Floe
  class Workflow
    class ChoiceRule
      class Data < Floe::Workflow::ChoiceRule
        TYPES      = ["String", "Numeric", "Boolean", "Timestamp", "Present", "Null"].freeze
        COMPARES   = ["Equals", "LessThan", "GreaterThan", "LessThanEquals", "GreaterThanEquals", "Matches"].freeze
        # e.g.: (Is)(String), (Is)(Present)
        TYPE_CHECK = /^(Is)(#{TYPES.join("|")})$/.freeze
        # e.g.: (String)(LessThan)(Path), (Numeric)(GreaterThanEquals)()
        OPERATION  = /^(#{(TYPES - %w[Null Present]).join("|")})(#{COMPARES.join("|")})(Path)?$/.freeze

        attr_reader :variable, :compare_key, :type, :compare_predicate, :path

        def initialize(_workflow, _name, payload)
          super

          @variable = parse_path("Variable", payload)
          parse_compare_key
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
          else
            raise Floe::InvalidWorkflowError, "Invalid choice [#{compare_key}]"
          end
        end

        private

        def presence_check(context, input)
          # Get the right hand side for {"Variable": "$.foo", "IsPresent": true} i.e.: true
          # If true  then return true when present.
          # If false then return true when not present.
          predicate = compare_value(context, input)
          # Don't need the variable_value, just need to see if the path finds the value.
          variable_value(context, input)

          # The variable_value is present
          # If predicate is true, then presence check was successful, return true.
          predicate
        rescue Floe::PathError
          # variable_value is not present. (the path lookup threw an error)
          # If predicate is false, then it successfully wasn't present, return true.
          !predicate
        end

        # rubocop:disable Naming/PredicateName
        # rubocop:disable Style/OptionalBooleanParameter
        def is_null?(value, predicate = true)
          value.nil? == predicate
        end

        def is_present?(value, predicate = true)
          !value.nil? == predicate
        end

        def is_numeric?(value, predicate = true)
          value.kind_of?(Numeric) == predicate
        end

        def is_string?(value, predicate = true)
          value.kind_of?(String) == predicate
        end

        def is_boolean?(value, predicate = true)
          [true, false].include?(value) == predicate
        end

        def is_timestamp?(value, predicate = true)
          require "date"

          DateTime.rfc3339(value)
          predicate
        rescue TypeError, Date::Error
          !predicate
        end
        # rubocop:enable Naming/PredicateName
        # rubocop:enable Style/OptionalBooleanParameter

        # parse the compare key at initialization time
        def parse_compare_key
          payload.each_key do |key|
            # e.g. (String)(GreaterThan)(Path)
            if (match_values = OPERATION.match(key))
              @compare_key = key
              @type, _operator, @path = match_values.captures
              @compare_predicate = parse_predicate(payload, type)
              break
            end
            # e.g. (Is)(String)
            if TYPE_CHECK.match?(key)
              @compare_key = key
              # type: nil means no runtime type checking.
              @type = @path = nil
              @compare_predicate = parse_predicate(payload, "Boolean")
              break
            end
          end
          parser_error!("requires a compare key") unless compare_key
        end

        # parse predicate at initilization time
        # @return the right predicate attached to the compare key
        def parse_predicate(payload, data_type)
          path ? parse_path(compare_key, payload) : parse_field(compare_key, payload, data_type)
        end

        # @return right hand predicate - input path or static payload value)
        def compare_value(context, input)
          path ? fetch_path(compare_key, compare_predicate, context, input) : compare_predicate
        end

        # feth the variable value at runtime
        # @return variable value (left hand side )
        def variable_value(context, input)
          fetch_path("Variable", variable, context, input)
        end

        # parse path at initilization time
        # helper method to parse a path from the payload
        def parse_path(field_name, payload)
          value = payload[field_name]
          missing_field_error!(field_name) unless value
          wrap_parser_error(field_name, value) { Path.new(value) }
        end

        # parse predicate field at initialization time
        def parse_field(field_name, payload, data_type)
          value = payload[field_name]
          return value if correct_type?(value, data_type)

          invalid_field_error!(field_name, value, "required to be a #{data_type}")
        end

        # fetch a path at runtime
        def fetch_path(field_name, field_path, context, input)
          value = field_path.value(context, input)
          return value if type.nil? || correct_type?(value, type)

          runtime_field_error!(field_name, field_path.to_s, "required to point to a #{type}")
        end

        # if we have runtime checking, check against that type
        #   otherwise assume checking a TYPE_CHECK predicate and check against Boolean
        def correct_type?(value, data_type)
          send("is_#{data_type.downcase}?".to_sym, value)
        end
      end
    end
  end
end
