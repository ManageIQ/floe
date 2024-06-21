# frozen_string_literal: true

module Floe
  class Workflow
    class ChoiceRule
      class Data < Floe::Workflow::ChoiceRule
        TYPES       = {"String" => :is_string?, "Numeric" => :is_numeric?, "Boolean" => :is_boolean?, "Timestamp" => :is_timestamp?, "Present" => :is_present?, "Null" => :is_null?}.freeze
        OPERATIONS  = {"Equals" => :eq?, "LessThan" => :lt?, "GreaterThan" => :gt?, "LessThanEquals" => :lte?, "GreaterThanEquals" => :gte?, "Matches" => :matches?}.freeze
        UNARY_RULE  = /^(Is)(#{TYPES.keys.join("|")})$/.freeze
        BINARY_RULE = /^(#{(TYPES.keys - %w[Null Present]).join("|")})(#{OPERATIONS.keys.join("|")})(Path)?$/.freeze

        attr_reader :compare_key, :operation, :type, :value, :path, :type_check

        def initialize(payload)
          super

          @compare_key = payload.keys.detect { |key| key.match?(UNARY_RULE) || key.match?(BINARY_RULE) }
          payload.error!("requires compare_key field") if @compare_key.nil?

          operator, @type = UNARY_RULE.match(compare_key)&.captures
          if operator
            @path = false
            @value = payload.boolean!(compare_key)
            @operation = TYPES[@type]
          else
            @type, operator, @path = BINARY_RULE.match(compare_key)&.captures
            @operation = OPERATIONS[operator]
            @type_check = TYPES[@type]

            if path
              @value = payload.path!(compare_key)
            else
              @value = payload[compare_key]
              payload.error!("requires #{type} field \"#{compare_key}\" but got [#{value}]") unless send(type_check, value)
            end
          end
        end

        def true?(context, input)
          lhs = variable_value(context, input)
          rhs = compare_value(context, input)

          send(operation, lhs, rhs)
        end

        private

        def is_null?(value, expected = true) # rubocop:disable Naming/PredicateName
          value.nil? == expected
        end

        def is_present?(value, expected = true) # rubocop:disable Naming/PredicateName
          !value.nil? == expected
        end

        def is_numeric?(value, expected = true) # rubocop:disable Naming/PredicateName
          (value.kind_of?(Integer) || value.kind_of?(Float)) == expected
        end

        def is_string?(value, expected = true) # rubocop:disable Naming/PredicateName
          value.kind_of?(String) == expected
        end
        alias is_path? is_string?

        def is_boolean?(value, expected = true) # rubocop:disable Naming/PredicateName
          [true, false].include?(value) == expected
        end

        def is_timestamp?(value, expected = true) # rubocop:disable Naming/PredicateName
          return !expected if value.nil? 

          require "date"

          DateTime.rfc3339(value)
          expected
        rescue TypeError, Date::Error
          !expected
        end

        def eq?(lhs, rhs)
          send(type_check, lhs) && send(type_check, rhs) && lhs == rhs
        end

        def lt?(lhs, rhs)
          send(type_check, lhs) && send(type_check, rhs) && lhs < rhs
        end

        def gt?(lhs, rhs)
          send(type_check, lhs) && send(type_check, rhs) && lhs > rhs
        end

        def lte?(lhs, rhs)
          send(type_check, lhs) && send(type_check, rhs) && lhs <= rhs
        end

        def gte?(lhs, rhs)
          send(type_check, lhs) && send(type_check, rhs) && lhs >= rhs
        end

        def matches?(lhs, rhs)
          send(type_check, lhs) && send(type_check, rhs) &&
            lhs.match?(Regexp.escape(rhs).gsub('\*', '.*?'))
        end

        def compare_value(context, input)
          path ? value.value(context, input) : value
        end
      end
    end
  end
end
