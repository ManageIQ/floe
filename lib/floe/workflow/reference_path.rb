# frozen_string_literal: true

module Floe
  class Workflow
    class ReferencePath < Path
      class << self
        def get(payload, context)
          new(payload).get(context)
        end

        def set(payload, context, value)
          new(payload).set(context, value)
        end
      end

      attr_reader :path

      def initialize(*)
        super

        raise Floe::InvalidWorkflowError, "Invalid Reference Path" if payload.match?(/@|,|:|\?/)

        @path = JsonPath.new(payload)
                        .path[1..]
                        .map { |v| v.match(/\[(?<name>.+)\]/)["name"] }
                        .filter_map { |v| v[0] == "'" ? v.delete("'") : v.to_i }
      end

      def get(context)
        return context if path.empty?

        context.dig(*path)
      end

      def set(context, value)
        result = context.dup

        # If the payload is '$' then merge the value into the context
        # otherwise store the value under the path
        #
        # TODO: how to handle non-hash values, raise error if path=$ and value not a hash?
        if path.empty?
          result.merge!(value)
        else
          child    = result
          keys     = path.dup
          last_key = keys.pop

          keys.each do |key|
            child[key] = {} if child[key].nil?
            child = child[key]
          end

          child[last_key] = value
        end

        result
      end
    end
  end
end
