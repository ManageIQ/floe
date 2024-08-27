require "parslet"

module Floe
  class Workflow
    class IntrinsicFunction
      def self.value(payload, context = {}, input = {})
        new(payload).value(context, input)
      end

      def self.intrinsic_function?(payload)
        payload.start_with?("States.")
      end

      def initialize(payload)
        @tree    = Parser.new.parse(payload)

        Floe.logger.debug { "Parsed intrinsic function: #{payload.inspect} => #{tree.inspect}" }
      rescue Parslet::ParseFailed => err
        raise Floe::InvalidWorkflowError, err.message
      end

      def value(context = {}, input = {})
        Transformer.new.apply(tree, :context => context, :input => input)
      end

      private

      attr_reader :tree
    end
  end
end
