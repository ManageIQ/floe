require "floe/builtin_runner/runner"
require "floe/builtin_runner/methods"

module Floe
  module BuiltinRunner
    SCHEME        = "floe".freeze
    SCHEME_PREFIX = "#{SCHEME}://".freeze

    class << self
      def error!(runner_context = {}, cause:, error: "States.TaskFailed")
        runner_context.merge!(
          "running" => false, "success" => false, "output" => {"Error" => error, "Cause" => cause}
        )
      end

      def success!(runner_context = {}, output:)
        runner_context.merge!(
          "running" => false, "success" => true, "output" => output
        )
      end
    end
  end
end

Floe::Runner.register_scheme(Floe::BuiltinRunner::SCHEME, -> { Floe::BuiltinRunner::Runner.new })
