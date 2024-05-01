# frozen_string_literal: true

module Floe
  class AwesomeRunner < Floe::Runner
    SCHEME        = "awesome"
    SCHEME_PREFIX = "#{SCHEME}://"
    SCHEME_OFFSET = SCHEME.length + 3

    def initialize(_options = {})
      require "awesome_spawn"

      super
    end

    # @return [Hash] runner_context
    def run_async!(resource, params = {}, _secrets = {}, _context = {})
      raise ArgumentError, "Invalid resource" unless resource&.start_with?(SCHEME_PREFIX)

      args = resource[SCHEME_OFFSET..].split
      method = args.shift

      runner_context = {}

      # TODO: fix sanitization preventing params in args (e.g.: $PARAM1 => \$PARAM1)
      result = AwesomeSpawn.run(method, :env => params, :params => args)
      self.class.populate_results!(runner_context, :result => result)
      runner_context
    end

    def status!(runner_context)
    end

    def running?(runner_context)
      !runner_context["Output"]
    end

    def success?(runner_context)
      !runner_context["Error"]
    end

    def output(runner_context)
      runner_context["Output"]
    end

    def cleanup(runner_context)
    end

    # internal methods

    def self.command_error_cause(command_result)
      command_result.error.nil? || command_result.error.empty? ? command_result.output.to_s : command_result.error.to_s
    end

    def self.populate_results!(runner_context, result: nil, error: nil)
      error ||= command_error_cause(result) if result&.failure?

      if error
        runner_context["Output"] = {"Error" => "States.TaskFailed", "Cause" => error}
        runner_context["Error"]  = true
      else
        runner_context["Output"] = {"Result" => result.output.chomp.split("\n")}
      end

      runner_context
    end
  end
end

Floe::Runner.register_scheme(Floe::AwesomeRunner::SCHEME, Floe::AwesomeRunner.new)
