# frozen_string_literal: true

module Floe
  class Workflow
    class IntrinsicFunction
      class << self
        def klass(payload)
          function_module_name, function_name =
            payload.match(/^(?<module>\w+)\.(?<function>\w+)\(.*\)$/)
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

        private alias_method :orig_new, :new

        def new(*args)
          if self == Floe::Workflow::IntrinsicFunction
            klass(*args).new(*args)
          else
            orig_new(*args)
          end
        end
      end

      attr_reader :args

      def initialize(payload)
        args  = payload.match(/^\w+\.\w+\((.*)\)$/).captures.first
        @args = args.split(", ").map do |arg|
          if arg.start_with?("$.")
            Path.new(arg)
          elsif arg.match?(/^\w+\.\w+\(.*\)$/)
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
