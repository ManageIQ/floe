# frozen_string_literal: true

module Floe
  class Workflow
    class Runner
      class Docker < Floe::Workflow::Runner
        include DockerMixin

        def initialize(options = {})
          require "awesome_spawn"
          require "tempfile"

          super

          @network = options.fetch("network", "bridge")
        end

        def run_async!(resource, env = {}, secrets = {})
          raise ArgumentError, "Invalid resource" unless resource&.start_with?("docker://")

          image = resource.sub("docker://", "")

          runner_context = {}

          if secrets && !secrets.empty?
            runner_context["secrets_ref"] = create_secret(secrets)
          end

          begin
            runner_context["container_ref"] = run_container(image, env, runner_context["secrets_ref"])
          rescue
            cleanup(runner_context)
            raise
          end

          runner_context
        end

        def cleanup(runner_context)
          container_id, secrets_file = runner_context.values_at("container_ref", "secrets_ref")

          delete_container(container_id) if container_id
          File.unlink(secrets_file)      if secrets_file && File.exist?(secrets_file)
        end

        def status!(runner_context)
          return unless runner_context["container_state"].nil? || running?(runner_context)

          runner_context["container_state"] = inspect_container(runner_context["container_ref"]).first&.dig("State")
        end

        def running?(runner_context)
          runner_context.dig("container_state", "Running")
        end

        def success?(runner_context)
          runner_context.dig("container_state", "ExitCode") == 0
        end

        def output(runner_context)
          runner_context["output"] ||= docker!("logs", runner_context["container_ref"], :combined_output => true).output
        end

        def mark_status(runner_context, type, error: true)
          runner_context["container_state"] = {"Running" => false, "ExitCode" => error ? 999 : 0}
          runner_context["output"] = type
        end

        private

        attr_reader :network

        def run_container(image, env, secrets_file)
          params  = ["run"]
          params << :detach
          params += env.map { |k, v| [:e, "#{k}=#{v}"] }
          params << [:e, "_CREDENTIALS=/run/secrets"] if secrets_file
          params << [:net, "host"] if @network == "host"
          params << [:v, "#{secrets_file}:/run/secrets:z"] if secrets_file
          params << [:name, container_name(image)]
          params << image

          logger.debug("Running docker: #{AwesomeSpawn.build_command_line("docker", params)}")

          result = docker!(*params)
          result.output
        end

        def inspect_container(container_id)
          JSON.parse(docker!("inspect", container_id).output)
        end

        def delete_container(container_id)
          docker!("rm", container_id)
        rescue
          nil
        end

        def create_secret(secrets)
          secrets_file = Tempfile.new
          secrets_file.write(secrets.to_json)
          secrets_file.close
          secrets_file.path
        end

        def docker!(*params, **kwargs)
          AwesomeSpawn.run!("docker", :params => params, **kwargs)
        end
      end
    end
  end
end
