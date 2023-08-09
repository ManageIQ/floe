# frozen_string_literal: true

module Floe
  class Workflow
    class IntrinsicFunction
      INTRINSIC_FUNCTION_REGEX = /^(?<module>\w+)\.(?<function>\w+)\((?<args>.*)\)$/.freeze

      class << self
        def new(*args)
          if self == Floe::Workflow::IntrinsicFunction
            detect_class(*args).new(*args)
          else
            super
          end
        end

        private def detect_class(payload)
          function_module_name, function_name =
            payload.match(INTRINSIC_FUNCTION_REGEX)
                   .named_captures
                   .values_at("module", "function")

          begin
            function_module = Floe::Workflow::IntrinsicFunctions.const_get(function_module_name)
            function_module.const_get(function_name)
          rescue NameError
            raise NotImplementedError, "#{function_module_name}.#{function_name} is not implemented"
          end
        end

        def value(payload, context, input = {})
          new(payload).value(context, input)
        end
      end

      attr_reader :args

      def initialize(payload)
        args  = payload.match(INTRINSIC_FUNCTION_REGEX).named_captures["args"]
        @args = args.split(", ").map do |arg|
          if arg.start_with?("$.")
            Path.new(arg)
          elsif arg.match?(INTRINSIC_FUNCTION_REGEX)
            Floe::Workflow::IntrinsicFunction.new(arg)
          else
            arg
          end
        end
      end

      def value(_context, _inputs)
        raise NotImplementedError, "must be implemented in a subclass"
      end
    end
  end
end
