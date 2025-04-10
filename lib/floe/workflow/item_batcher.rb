# frozen_string_literal: true

module Floe
  class Workflow
    class ItemBatcher
      include ValidationMixin

      attr_reader :name, :batch_input, :max_items_per_batch, :max_items_per_batch_path, :max_input_bytes_per_batch, :max_input_bytes_per_batch_path

      def initialize(payload, name)
        @name = name

        @batch_input               = PayloadTemplate.new(payload["BatchInput"]) if payload["BatchInput"]
        @max_items_per_batch       = payload["MaxItemsPerBatch"]
        @max_input_bytes_per_batch = payload["MaxInputBytesPerBatch"]

        @max_items_per_batch_path       = ReferencePath.new(payload["MaxItemsPerBatchPath"])      if payload["MaxItemsPerBatchPath"]
        @max_input_bytes_per_batch_path = ReferencePath.new(payload["MaxInputBytesPerBatchPath"]) if payload["MaxInputBytesPerBatchPath"]

        validate!
      end

      def value(context, input, state_input = nil)
        state_input ||= input

        output = batch_input ? batch_input.value(context, state_input) : {}

        input.each_slice(max_items(context, state_input)).map do |batch|
          output.merge("Items" => batch)
        end
      end

      private

      def max_items(context, state_input)
        return    max_items_per_batch if max_items_per_batch
        return if max_items_per_batch_path.nil?

        result = max_items_per_batch_path.value(context, state_input)
        raise runtime_field_error!("MaxItemsPerBatchPath", result, "must be a positive integer") if result.nil? || !result.kind_of?(Integer) || result <= 0

        result
      end

      def validate!
        if [max_items_per_batch, max_items_per_batch_path].all?(&:nil?)
          parser_error!("must have one of \"MaxItemsPerBatch\", \"MaxItemsPerBatchPath\"")
        end

        parser_error!("must not specify both \"MaxItemsPerBatch\" and \"MaxItemsPerBatchPath\"")           if max_items_per_batch && max_items_per_batch_path
        parser_error!("must not specify both \"MaxInputBytesPerBatch\" and \"MaxInputBytesPerBatchPath\"") if max_input_bytes_per_batch && max_input_bytes_per_batch_path

        if max_items_per_batch && (!max_items_per_batch.kind_of?(Integer) || max_items_per_batch <= 0)
          invalid_field_error!("MaxItemsPerBatch", max_items_per_batch, "must be a positive integer")
        end
        if max_input_bytes_per_batch && (!max_input_bytes_per_batch.kind_of?(Integer) || max_input_bytes_per_batch <= 0)
          invalid_field_error!("MaxInputBytesPerBatch", max_input_bytes_per_batch, "must be a positive integer")
        end
      end
    end
  end
end
