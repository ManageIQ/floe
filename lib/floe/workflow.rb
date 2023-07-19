# frozen_string_literal: true

require "securerandom"
require "json"

module Floe
  class Workflow
    class << self
      def load(path_or_io, context = nil, credentials = {})
        payload = path_or_io.respond_to?(:read) ? path_or_io.read : File.read(path_or_io)
        new(payload, context, credentials)
      end
    end

    attr_reader :context, :credentials, :payload, :states, :states_by_name

    # @param payload [JSON String|Hash] configuration of the workflow
    # @param context [JSON String|Hash|Context] runtime state for the workflow
    # @param credentials [JSON String|Hash]
    def initialize(payload, context = nil, credentials = {})
      payload     = JSON.parse(payload)     if payload.kind_of?(String)
      context     = JSON.parse(context)     if context.kind_of?(String)
      credentials = JSON.parse(credentials) if credentials.kind_of?(String)
      context     = Context.new(context)    unless context.kind_of?(Context)

      @payload     = payload
      @context     = context || {"global" => {}}
      @credentials = credentials

      # I had thought name was inside the state values?
      @states         = payload["States"].to_a.map { |name, state| State.build!(self, name, state) }
      @states_by_name = @states.index_by(&:name)
    rescue JSON::ParserError => err
      raise Floe::InvalidWorkflowError, err.message
    end

    def step
      next_states = []
      context.active_states.each do |state_context|
        state_name = state_context["Name"]
        state = @states_by_name[state_name]

        case state_context["Status"]
        when "pending" # this is ready to start running
          next_states << kickoff(state_context)
        when "running" # only for async processes
          # TODO: next_states << @states_by_name[state_name].check_in(state_context)
          next_states << state_context
        when "success", "completed", "fail"
          # add co context
          context.states << state_context
          if (parent_guid = state_context["Parent"])
            # ping parent
            # in the end, this will be a different list of states
            # maybe lookup via state name?
            parent_state_context = context.active_states.detect { |parent_state_context| parent_state_context["Guid"] == parent_guid }
            parent_state_context["ChildStates"] << state_context
          end
        end
      end

      context.active_states = next_states
      context.execution["Status"] = status

      self
    end

    def run!
      # wonder if this lives in context.
      context.active_states = [create_state_context(payload["StartAt"], context.execution["Input"].dup)]

      until end?
        step
      end

      context.execution["Status"] = context.last_active_state["Status"]
      context.execution["Output"] = context.last_active_state["Output"]

      self
    end

    # @return Array<StateContext>
    #   for async: own context
    #   for sync: next context
    #   for parallel, own and child contexts
    def kickoff!(context)
      context["EnteredTime"]  = Time.now.utc,
      context["Status"]       = "running"
      context["StartTime"]    = Time.now.utc.iso8601

      tick = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      next_state, output = @states_by_name[state_name].run!(context["Input"])
      tock = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      # assuming 
      context["Status"]       = "success" # error...
      context["FinishedTime"] = Time.now.utc
      context["Duration"]     = (tock - tick) / 1_000_000.0
      context["Output"]       = output

      # future: run! returns a new context
      if next_state != context["Name"]
        next_state = create_state_context(next_state, context["Output"])
      else
        next_state = []
      end

      next_state + [context]
    end

    # TODO: use context.active_statues
    def end?
      active_states.empty?
    end

    def status
      context.execution["Status"]
    end

    # TODO: this belongs in the context
    def self.create_state_context(name, input, parent_guid = nil)
      {
        "Name"   => name,
        "Status" => "pending",
        "Done"   => false, # needed?
        "Guid"   => SecureRandom.uuid,
        "Input"  => input,
        "Parent" => parent_guid
      }.compact # remove null parent_guid
    end
  end
end
