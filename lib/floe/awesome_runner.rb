# frozen_string_literal: true

require "concurrent/array"

module Floe
  class AwesomeProcess < Thread
    attr_reader :result
    attr_accessor :error

    def initialize(queue, context, *args)
      self.report_on_exception = true
      @processed = false
      @context = context

      # Don't like changing the value of context here,
      # but want to make sure thread is set before the `queue.push`
      # `queue.pop` will look potentially at status, which is through thread
      context["thread"] = self

      super do
        @result = AwesomeSpawn.run(*args)

        # this is changing the value of the context
        # in the non-main thread
        # Potential race condition here
        Floe::AwesomeRunner.populate_results!(@context, :result => @result)

        # trigger an event
        queue.push(["delete", context])
      rescue => err
        # Shouldn't ever get in here
        @error = err

        Floe::AwesomeRunner.populate_results!(@context, :error => err)

        # trigger an event
        queue.push(["delete", context])
      end
    end
  end

  class AwesomeRunner < Floe::Runner
    SCHEME        = "awesome"
    SCHEME_PREFIX = "#{SCHEME}://"
    SCHEME_OFFSET = SCHEME.length + 3

    # only exposed for tests
    # use wait instead
    attr_reader :queue

    def initialize(_options = {})
      require "awesome_spawn"

      # events triggered
      @queue = Queue.new

      super
    end

    # @return [Hash] runner_context
    def run_async!(resource, params = {}, _secrets = {}, _context = {})
      raise ArgumentError, "Invalid resource" unless resource&.start_with?(SCHEME_PREFIX)

      args = resource[SCHEME_OFFSET..].split
      method = args.shift

      runner_context = {}

      # NOTE: this adds itself to the runner_context
      AwesomeProcess.new(@queue, runner_context, method, :env => params, :params => args)

      runner_context
    end

    def status!(runner_context)
      # check if it has no output (i.e.: we think it is running) but it is not running
      if !runner_context.key?("Output") && !runner_context["thread"]&.alive?
        runner_context["Output"] = {"Error" => "Lambda.Unknown", "Cause" => "no output and no thread"}
        runner_context["Error"]  = true
      end
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
      runner_context["thread"] = nil
    end

    def wait(timeout: nil, _events: %i[create update delete])
      # TODO: implement whole interface
      raise "wait needs a block and doesn't support timeout" unless timeout.nil? && block_given?

      loop do
        event_context = @queue.pop
        yield event_context if block_given?
      end
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
