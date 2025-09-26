# frozen_string_literal: true

module Floe
  class Workflow
    class Path
      class << self
        def path?(payload)
          payload.start_with?("$")
        end

        def value(payload, context, input = {})
          new(payload).value(context, input)
        end
      end

      attr_reader :payload

      def initialize(payload)
        @payload = payload

        raise Floe::InvalidWorkflowError, "Path [#{payload}] must be a string" if payload.nil? || !payload.kind_of?(String)
        raise Floe::InvalidWorkflowError, "Path [#{payload}] must start with \"$\"" if payload[0] != "$"
      end

      def value(context, input = {})
        obj, path =
          if payload.start_with?("$$")
            [context, payload[1..]]
          else
            [input, payload]
          end

        # If path is $ then just return the entire input
        return obj if path == "$"

        results = JsonPath.on(obj, path)
        case results.count
        when 0
          raise Floe::PathError, "references an invalid value"
        when 1
          results.first
        else
          results
        end
      end

      def to_s
        payload
      end
    end
  end
end
