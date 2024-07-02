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
          quote >> (
            (str('\\') >> any) | (quote.absent? >> any)
          ).repeat.as(:string) >> quote
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
          :states_array,           "States.Array",
          :states_array_partition, "States.ArrayPartition",
          :states_uuid,            "States.UUID",
        ].each_slice(2) do |function_symbol, function_name|
          rule(function_symbol) do
            (
              str(function_name) >> str('(') >> args >> str(')')
            ).as(function_symbol)
          end
        end

        rule(:expression) { states_array | states_array_partition | states_uuid }
        root(:expression)
      end
    end
  end
end
