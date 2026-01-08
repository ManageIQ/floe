require "floe"
require "floe/cli/logger"
require "floe/container_runner"
require "optimist"
require "stringio"

module Floe
  class CLI
    include Logging

    def initialize
      Floe.logger = ::Logger.new($stdout)
      Floe.logger.level = 0 if ENV["DEBUG"]
    end

    def run(args = ARGV)
      workflows_inputs, opts = parse_options!(args)

      show_execution_id = workflows_inputs.size > 1

      credentials = create_credentials(opts)

      workflows =
        workflows_inputs.map do |workflow, input|
          wf_logger = create_logger(show_execution_id)
          create_workflow(workflow, opts[:context], input, credentials, wf_logger)
        end

      logger.info("Checking #{workflows.count} workflows...")
      ready = Floe::Workflow.wait(workflows, &:run_nonblock)
      logger.info("Checking #{workflows.count} workflows...Complete - #{ready.count} ready")

      # Display status
      workflows.each do |workflow|
        if workflows.size > 1
          logger.info("")
          logger.info("#{workflow.name} [#{workflow.context.execution_id}]#{" (#{workflow.status})" unless workflow.context.success?}")
          logger.info("===")
        end
        logger.info(workflow.output)
      end

      workflows.all? { |workflow| workflow.context.success? }
    rescue Floe::Error => err
      abort(err.message)
    end

    private

    def parse_options!(args)
      opts = Optimist.options(args) do
        version("v#{Floe::VERSION}\n")
        usage("[options] workflow input [workflow2 input2]")

        opt :workflow, "Path to your workflow json file (alternative to passing a bare workflow)", :type => :string
        opt :input, <<~EOMSG, :type => :string
          JSON payload of the Input to the workflow
            If --input is passed and --workflow is not passed, will be used for all bare workflows listed.
            If --input is not passed and --workflow is passed, defaults to '{}'.
        EOMSG
        opt :context, "JSON payload of the Context",              :type => :string
        opt :credentials, "JSON payload with Credentials",        :type => :string
        opt :credentials_file, "Path to a file with Credentials", :type => :string

        Floe::ContainerRunner.cli_options(self)

        banner("")
        banner("General options:")
      end

      # Create workflow/input pairs from the various combinations of parameters
      workflows_inputs =
        if opts[:workflow_given]
          Optimist.die("cannot specify both --workflow and bare workflows") if args.any?

          [[opts[:workflow], opts.fetch(:input, "{}")]]
        elsif opts[:input_given]
          Optimist.die("workflow(s) must be specified") if args.empty?

          args.map { |w| [w, opts[:input].dup] }
        else
          Optimist.die("workflow/input pairs must be specified") if args.empty? || (args.size > 1 && args.size.odd?)

          args.each_slice(2).to_a
        end

      Floe::ContainerRunner.resolve_cli_options!(opts)

      return workflows_inputs, opts
    end

    def create_credentials(opts)
      credentials_str = if opts[:credentials_given]
                          opts[:credentials] == "-" ? $stdin.read : opts[:credentials]
                        elsif opts[:credentials_file_given]
                          File.read(opts[:credentials_file])
                        else
                          return
                        end
      JSON.parse(credentials_str)
    end

    def create_workflow(workflow, context_payload, input, credentials, logger)
      context = Floe::Workflow::Context.new(context_payload, :input => input, :credentials => credentials, :logger => logger)
      Floe::Workflow.load(workflow, context)
    end

    def create_logger(show_execution_id)
      logger_class = show_execution_id ? Floe::CLI::Logger : ::Logger
      logger_class.new($stdout).tap do |logger|
        logger.level = 0 if ENV["DEBUG"]
      end
    end
  end
end
