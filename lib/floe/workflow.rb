# frozen_string_literal: true

require "securerandom"
require "json"

module Floe
  class Workflow
    include Logging

    class << self
      def load(path_or_io, credentials = {})
        payload = path_or_io.respond_to?(:read) ? path_or_io.read : File.read(path_or_io)
        new(payload, credentials)
      end
    end

    attr_reader :context, :credentials, :payload, :states, :states_by_name, :start_at

    def initialize(payload, credentials = {})
      payload     = JSON.parse(payload)     if payload.kind_of?(String)
      credentials = JSON.parse(credentials) if credentials.kind_of?(String)

      @payload     = payload
      @credentials = credentials
      @start_at    = payload["StartAt"]

      @states         = payload["States"].to_a.map { |name, state| State.build!(self, name, state) }
      @states_by_name = @states.each_with_object({}) { |state, result| result[state.name] = state }
    rescue JSON::ParserError => err
      raise Floe::InvalidWorkflowError, err.message
    end

    def step(context)
      if context.next_state
        context.start_next_state!
      elsif !context.state_name
        context.start_next_state!(start_at)
      end

      logger.info("Running state: [#{context.state_name}] with input [#{context.input}]...")

      context.state["EnteredTime"] = Time.now.utc

      current_state = @states_by_name[context.state_name]
      tick = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      current_state.run!(context.input)
      tock = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      context.state["FinishedTime"] = Time.now.utc
      context.state["Duration"]     = tock - tick

      logger.info("Running state: [#{context.state_name}] with input [#{context.input}]...Complete - next state: [#{context.next_state}] output: [#{context.output}]")

      context.state_history << context.state

      context
    end

    def run!(context)
      until context.ended?
        step(context)
      end

      context
    end
  end
end
