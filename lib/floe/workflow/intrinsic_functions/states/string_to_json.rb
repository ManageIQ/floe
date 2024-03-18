# frozen_string_literal: true

module Floe
  class Workflow
    module IntrinsicFunctions
      module States
        class StringToJson < Floe::Workflow::IntrinsicFunction
          def value(context, inputs)
            arg = args.first
            arg = arg.value(context, inputs) if arg.respond_to?(:value)

            JSON.parse(arg)
          end
        end
      end
    end
  end
end
