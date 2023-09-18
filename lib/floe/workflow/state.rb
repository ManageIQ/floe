# frozen_string_literal: true

module Floe
  class Workflow
    class State
      include Logging

      class << self
        def build!(name, payload, credentials = nil)
          state_type = payload["Type"]

          begin
            klass = Floe::Workflow::States.const_get(state_type)
          rescue NameError
            raise Floe::InvalidWorkflowError, "Invalid state type: [#{state_type}]"
          end

          klass.new(name, payload, credentials)
        end
      end

      attr_reader :comment, :name, :type, :payload

      def initialize(name, payload, _credentials = nil)
        @name     = name
        @payload  = payload
        @type     = payload["Type"]
        @comment  = payload["Comment"]
      end
    end
  end
end
