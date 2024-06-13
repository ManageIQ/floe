# frozen_string_literal: true

module Floe
  class Workflow
    class ChoiceRule
      class Data < Floe::Workflow::ChoiceRule
        TYPES      = {"String" => :is_string?, "Numeric" => :is_numeric?, "Boolean" => :is_boolean?, "Timestamp" => :is_timestamp?, "Present" => :is_present?, "Null" => :is_null?}.freeze
        COMPARES   = {"Equals" => :eq?, "LessThan" => :lt?, "GreaterThan" => :gt?, "LessThanEquals" => :lte?, "GreaterThanEquals" => :gte?, "Matches" => :matches?}.freeze
        # e.g.: (Is)(String), (Is)(Present)
        TYPE_CHECK = /^(Is)(#{TYPES.keys.join("|")})$/.freeze
        # e.g.: (String)(LessThan)(Path), (Numeric)(GreaterThanEquals)()
        OPERATION  = /^(#{(TYPES.keys - %w[Null Present]).join("|")})(#{COMPARES.keys.join("|")})(Path)?$/.freeze

        attr_reader :variable, :compare_key, :operation, :type, :compare_predicate, :path

        def initialize(_workflow, _name, payload)
          super

          @variable = parse_path("Variable", payload)
          parse_compare_key(payload)
          @compare_predicate = parse_predicate(payload)
        end

        def true?(context, input)
          return presence_check(context, input) if compare_key == "IsPresent"

          lhs = variable_value(context, input)
          rhs = compare_value(context, input)

          raise Floe::InvalidWorkflowError, "Invalid choice [#{compare_key}]" if operation.nil?
          send(operation, lhs, rhs)
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

        def eq?(lhs, rhs)
          lhs == rhs
        end

        def lt?(lhs, rhs)
          lhs < rhs
        end

        def gt?(lhs, rhs)
          lhs > rhs
        end

        def lte?(lhs, rhs)
          lhs <= rhs
        end

        def gte?(lhs, rhs)
          lhs >= rhs
        end

        def matches?(lhs, rhs)
          lhs.match?(Regexp.escape(rhs).gsub('\*', '.*?'))
        end

        # parse the compare key at initialization time
        def parse_compare_key(payload)
          payload.each_key do |key|
            # e.g. (String)(GreaterThan)(Path)
            if (match_values = OPERATION.match(key))
              @compare_key = key
              @type, operator, @path = match_values.captures
              @operation = COMPARES[operator]
              break
            end
            # e.g. (Is)(String)
            if (match_value = TYPE_CHECK.match(key))
              @compare_key = key
              _operator, type = match_value.captures
              @type = @path = nil
              @operation = TYPES[type]
              break
            end
          end
          parser_error!("requires a compare key") unless @compare_key
        end

        # parse predicate at initilization time
        # @return the right predicate attached to the compare key
        def parse_predicate(payload)
          path ? parse_path(compare_key, payload) : parse_value(compare_key, payload)
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

        def parse_value(field_name, payload)
          value = payload[field_name]
          invalid_field_error!(field_name, value, "required to be a #{type || "Boolean"}") unless correct_type?(value)
          value
        end

        # fetch a path at runtime
        # @ the value at a path
        def fetch_path(field_name, field_path, context, input)
          ret_value = field_path.value(context, input)
          runtime_field_error!(field_name, field_path.to_s, "required to point to a #{type}") if type && !correct_type?(ret_value)
          ret_value
        end

        def correct_type?(val)
          send(TYPES[type || "Boolean"], val)
        end
      end
    end
  end
end
