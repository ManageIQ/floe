# frozen_string_literal: true

module Floe
  class Workflow
    class Runner
      class Podman < Floe::Workflow::Runner
        include DockerMixin

        def initialize(options = {})
          require "awesome_spawn"
          require "securerandom"

          super

          @identity        = options["identity"]
          @log_level       = options["log-level"]
          @network         = options["network"]
          @noout           = options["noout"].to_s == "true" if options.key?("noout")
          @root            = options["root"]
          @runroot         = options["runroot"]
          @runtime         = options["runtime"]
          @runtime_flag    = options["runtime-flag"]
          @storage_driver  = options["storage-driver"]
          @storage_opt     = options["storage-opt"]
          @syslog          = options["syslog"].to_s == "true" if options.key?("syslog")
          @tmpdir          = options["tmpdir"]
          @transient_store = !!options["transient-store"] if options.key?("transient-store")
          @volumepath      = options["volumepath"]
        end

        def run_async!(resource, env = {}, secrets = {})
          raise ArgumentError, "Invalid resource" unless resource&.start_with?("docker://")

          image = resource.sub("docker://", "")

          if secrets && !secrets.empty?
            secret_guid = create_secret(secrets)
          end

          begin
            container_id = run_container(image, env, secret_guid)
          rescue
            cleanup({"container_ref" => container_id, "secrets_ref" => secret_guid})
            raise
          end

          {"container_ref" => container_id, "secrets_ref" => secret_guid}
        end

        def cleanup(runner_context)
          container_id, secret_guid = runner_context.values_at("container_ref", "secrets_ref")

          delete_container(container_id) if container_id
          delete_secret(secret_guid)     if secret_guid
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
          runner_context["output"] ||= podman!("logs", runner_context["container_ref"], :combined_output => true).output
        end

        private

        def run_container(image, env, secret)
          params  = ["run"]
          params << :detach
          params += env.map { |k, v| [:e, "#{k}=#{v}"] }
          params << [:e, "_CREDENTIALS=/run/secrets/#{secret}"] if secret
          params << [:net, "host"] if @network == "host"
          params << [:secret, secret] if secret
          params << [:name, container_name(image)]
          params << image

          logger.debug("Running podman: #{AwesomeSpawn.build_command_line("podman", params)}")

          result = podman!(*params)
          result.output
        end

        def inspect_container(container_id)
          JSON.parse(podman!("inspect", container_id).output)
        end

        def delete_container(container_id)
          podman!("rm", container_id)
        rescue
          nil
        end

        def create_secret(secrets)
          secret_guid = SecureRandom.uuid
          podman!("secret", "create", secret_guid, "-", :in_data => secrets.to_json)
          secret_guid
        end

        def delete_secret(secret_guid)
          podman!("secret", "rm", secret_guid)
        rescue
          nil
        end

        def podman!(*args, **kwargs)
          params = podman_global_options + args

          AwesomeSpawn.run!("podman", :params => params, **kwargs)
        end

        def podman_global_options
          options = []
          options << [:identity, @identity]                 if @identity
          options << [:"log-level", @log_level]             if @log_level
          options << :noout                                 if @noout
          options << [:root, @root]                         if @root
          options << [:runroot, @runroot]                   if @runroot
          options << [:runtime, @runtime]                   if @runtime
          options << [:"runtime-flag", @runtime_flag]       if @runtime_flag
          options << [:"storage-driver", @storage_driver]   if @storage_driver
          options << [:"storage-opt", @storage_opt]         if @storage_opt
          options << :syslog                                if @syslog
          options << [:tmpdir, @tmpdir]                     if @tmpdir
          options << [:"transient-store", @transient_store] if @transient_store
          options << [:volumepath, @volumepath]             if @volumepath
          options
        end
      end
    end
  end
end
