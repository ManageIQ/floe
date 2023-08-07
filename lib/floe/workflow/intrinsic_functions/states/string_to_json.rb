# frozen_string_literal: true

module Floe
  class Workflow
    module IntrinsicFunctions
      module States
        class StringToJson < Floe::Workflow::IntrinsicFunction
          def value(context, inputs)
            arg = args.first
            arg =
              if arg.kind_of?(Floe::Workflow::Path) || arg.kind_of?(Floe::Workflow::IntrinsicFunction)
                arg.value(context, inputs)
              else
                arg
              end

            JSON.parse(arg)
          end
        end
      end
    end
  end
end
