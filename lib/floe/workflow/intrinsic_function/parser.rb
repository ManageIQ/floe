require "parslet"

module Floe
  class Workflow
    class IntrinsicFunction
      class Parser < Parslet::Parser
        rule(:spaces)  { str(' ').repeat(1) }
        rule(:spaces?) { spaces.maybe }
        rule(:digit)   { match('[0-9]') }
        rule(:quote)   { str('\'') }

        rule(:comma_sep) { str(',') >> spaces? }

        rule(:true_literal)  { str('true').as(:true_literal) }
        rule(:false_literal) { str('false').as(:false_literal) }
        rule(:null_literal)  { str('null').as(:null_literal) }

        rule(:number) do
          (
            str('-').maybe >> (
              str('0') | (match('[1-9]') >> digit.repeat)
            ) >> (
              str('.') >> digit.repeat(1)
            ).maybe >> (
              match('[eE]') >> (str('+') | str('-')).maybe >> digit.repeat(1)
            ).maybe
          ).as(:number)
        end

        rule(:string) do
          (
            quote >> (
              (str('\\') >> any) | (quote.absent? >> any)
            ).repeat >> quote
          ).as(:string)
        end

        rule(:jsonpath) do
          (
            str('$') >> match('[^,)]').repeat(0)
          ).as(:jsonpath)
        end

        rule(:arg) do
          (
            string | number | jsonpath | true_literal | false_literal | null_literal | expression
          ).as(:arg)
        end

        rule(:args) do
          (
            arg >> (comma_sep >> arg).repeat
          ).maybe.as(:args)
        end

        [
          :states_format,          "States.Format",
          :states_string_to_json,  "States.StringToJson",
          :states_json_to_string,  "States.JsonToString",
          :states_array,           "States.Array",
          :states_array_partition, "States.ArrayPartition",
          :states_array_contains,  "States.ArrayContains",
          :states_array_range,     "States.ArrayRange",
          :states_array_get_item,  "States.ArrayGetItem",
          :states_array_length,    "States.ArrayLength",
          :states_array_unique,    "States.ArrayUnique",
          :states_base64_encode,   "States.Base64Encode",
          :states_base64_decode,   "States.Base64Decode",
          :states_hash,            "States.Hash",
          :states_math_random,     "States.MathRandom",
          :states_math_add,        "States.MathAdd",
          :states_string_split,    "States.StringSplit",
          :states_uuid,            "States.UUID",
        ].each_slice(2) do |function_symbol, function_name|
          rule(function_symbol) do
            (
              str(function_name) >> str('(') >> args >> str(')')
            ).as(function_symbol)
          end
        end

        rule(:expression) do
          states_format |
            states_string_to_json |
            states_json_to_string |
            states_array |
            states_array_partition |
            states_array_contains |
            states_array_range |
            states_array_get_item |
            states_array_length |
            states_array_unique |
            states_base64_encode |
            states_base64_decode |
            states_hash |
            states_math_random |
            states_math_add |
            states_string_split |
            states_uuid
        end

        root(:expression)
      end
    end
  end
end
