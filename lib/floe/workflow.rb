# frozen_string_literal: true

require "securerandom"
require "json"

module Floe
  class Workflow
    include Logging

    class << self
      def load(path_or_io, context = nil, credentials = {}, name = nil)
        payload = path_or_io.respond_to?(:read) ? path_or_io.read : File.read(path_or_io)
        # default the name if it is a filename and none was passed in
        name ||= path_or_io.respond_to?(:read) ? "stream" : path_or_io.split("/").last.split(".").first

        new(payload, context, credentials, name)
      end

      def wait(workflows, timeout: nil)
        logger.info("checking #{workflows.count} workflows...")

        start = Time.now.utc
        ready = []

        loop do
          ready = workflows.select(&:step_nonblock_ready?)
          break if timeout.zero? || Time.now.utc - start > timeout || !ready.empty?

          sleep(1)
        end

        logger.info("checking #{workflows.count} workflows...Complete - #{ready.count} ready")
        ready
      end
    end

    attr_reader :context, :credentials, :payload, :states, :states_by_name, :start_at, :name

    def initialize(payload, context = nil, credentials = {}, name = nil)
      payload     = JSON.parse(payload)     if payload.kind_of?(String)
      credentials = JSON.parse(credentials) if credentials.kind_of?(String)
      context     = Context.new(context)    unless context.kind_of?(Context)

      raise Floe::InvalidWorkflowError, "Missing field \"States\""  if payload["States"].nil?
      raise Floe::InvalidWorkflowError, "Missing field \"StartAt\"" if payload["StartAt"].nil?
      raise Floe::InvalidWorkflowError, "\"StartAt\" not in the \"States\" field" unless payload["States"].key?(payload["StartAt"])

      @name        = name
      @payload     = payload
      @context     = context
      @credentials = credentials || {}
      @start_at    = payload["StartAt"]

      @states         = payload["States"].to_a.map { |state_name, state| State.build!(self, state_name, state) }
      @states_by_name = @states.each_with_object({}) { |state, result| result[state.name] = state }

      unless context.state.key?("Name")
        context.state["Name"] = start_at
        context.state["Input"] = context.execution["Input"].dup
      end
    rescue JSON::ParserError => err
      raise Floe::InvalidWorkflowError, err.message
    end

    def run_nonblock
      loop while step_nonblock == 0 && !end?
      self
    end

    def step_nonblock
      return Errno::EPERM if end?

      step_next
      current_state.run_nonblock!
    end

    def step_nonblock_ready?
      current_state.ready?
    end

    def status
      context.status
    end

    def output
      context.output if end?
    end

    def end?
      context.ended?
    end

    def current_state
      @states_by_name[context.state_name]
    end

    private

    def step_next
      context.state = {"Name" => context.next_state, "Input" => context.output} if context.next_state
    end
  end
end
