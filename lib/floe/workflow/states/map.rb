# frozen_string_literal: true

require_relative "input_output_mixin"
require_relative "non_terminal_mixin"

module Floe
  class Workflow
    module States
      class Map < Floe::Workflow::State
        include InputOutputMixin
        include NonTerminalMixin

        attr_reader :end, :next, :parameters, :input_path, :output_path, :result_path,
                    :result_selector, :retry, :catch, :item_processor, :items_path,
                    :item_reader, :item_selector, :item_batcher, :result_writer,
                    :max_concurrency, :tolerated_failure_percentage, :tolerated_failure_count

        def initialize(workflow, name, payload)
          super

          raise Floe::InvalidWorkflowError, "Missing \"InputProcessor\" field in state [#{name.last}]" if payload["ItemProcessor"].nil?

          @next            = payload["Next"]
          @end             = !!payload["End"]
          @parameters      = PayloadTemplate.new(payload["Parameters"]) if payload["Parameters"]
          @input_path      = Path.new(payload.fetch("InputPath", "$"))
          @output_path     = Path.new(payload.fetch("OutputPath", "$"))
          @result_path     = ReferencePath.new(payload.fetch("ResultPath", "$"))
          @result_selector = PayloadTemplate.new(payload["ResultSelector"]) if payload["ResultSelector"]
          @retry           = payload["Retry"].to_a.map { |retrier| Retrier.new(retrier) }
          @catch           = payload["Catch"].to_a.map { |catcher| Catcher.new(catcher) }
          @item_processor  = ItemProcessor.new(payload["ItemProcessor"], name)
          @items_path      = ReferencePath.new(payload.fetch("ItemsPath", "$"))
          @item_reader     = payload["ItemReader"]
          @item_selector   = payload["ItemSelector"]
          @item_batcher    = payload["ItemBatcher"]
          @result_writer   = payload["ResultWriter"]
          @max_concurrency = payload["MaxConcurrency"]&.to_i
          @tolerated_failure_percentage = payload["ToleratedFailurePercentage"]
          @tolerated_failure_count      = payload["ToleratedFailureCount"]

          validate_state!(workflow)
        end

        def process_input(context)
          input = super
          items_path.value(context, input)
        end

        def start(context)
          super

          input = process_input(context)

          context.state["Iteration"] = 0
          context.state["MaxIterations"] = input.count
          context.state["Result"] = []
          context.state["ItemProcessorContext"] = input.map { |item| Context.new(nil, :input => item.to_json).to_h }
        end

        def finish(context)
          result = context.state["Result"]
          context.output = process_output(context, result)
          super
        end

        def run_nonblock!(context)
          start(context) unless context.state_started?
          loop while step_nonblock!(context) == 0 && running?(context)
          return Errno::EAGAIN unless ready?(context)

          finish(context)
        end

        def end?
          @end
        end

        def running?(context)
          # TODO: this only works with MaxConcurrency=1
          context.state["Iteration"] < context.state["MaxIterations"]
        end

        private

        def step_nonblock!(context)
          item_processor_context = Context.new(context.state["ItemProcessorContext"][context.state["Iteration"]])
          item_processor.run_nonblock(item_processor_context) if item_processor.step_nonblock_ready?(item_processor_context)
          if item_processor_context.ended?
            result = item_processor.output(item_processor_context)

            context.state["Result"] << JSON.parse(result)
            context.state["Iteration"] += 1
            0
          else
            Errno::EAGAIN
          end
        end

        def validate_state!(workflow)
          validate_state_next!(workflow)
        end
      end
    end
  end
end
