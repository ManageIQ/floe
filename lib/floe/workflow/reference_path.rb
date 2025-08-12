# frozen_string_literal: true

module Floe
  class Workflow
    class ReferencePath < Path
      attr_reader :path

      def initialize(*)
        super

        raise Floe::InvalidWorkflowError, "Invalid Reference Path"              if payload.match?(/@|,|:|\?/)
        raise Floe::InvalidWorkflowError, "Reference Path cannot start with $$" if payload.start_with?("$$") && !payload.start_with?("$$.Credentials")

        path_shift = payload.start_with?("$$.Credentials") ? 3 : 1

        @path = JsonPath.new(payload)
                        .path[path_shift..]
                        .map { |v| v.match(/\[(?<name>.+)\]/)["name"] }
                        .filter_map { |v| v[0] == "'" ? v.delete("'") : v.to_i }
      end

      def get(context)
        return context if path.empty?

        context.dig(*path)
      end

      def set(context, value)
        result = context.dup

        # If the payload is '$' then replace the output with the value
        if path.empty?
          result = value.dup
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
