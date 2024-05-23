# frozen_string_literal: true

require_relative "container_runner/docker_mixin"
require_relative "container_runner/docker"
require_relative "container_runner/kubernetes"
require_relative "container_runner/podman"

module Floe
  class ContainerRunner
    class << self
      def cli_options(optimist)
        optimist.banner("")
        optimist.banner("Container runner options:")

        optimist.opt :container_runner, "Type of runner for docker container images (docker, podman, or kubernetes)", :type => :string, :short => 'r'
        optimist.opt :container_runner_options, "Options to pass to the container runner", :type => :strings, :short => 'o'

        optimist.opt :docker,     "Use docker to run container images     (short for --container-runner=docker)",     :type => :boolean
        optimist.opt :podman,     "Use podman to run container images     (short for --container-runner=podman)",     :type => :boolean
        optimist.opt :kubernetes, "Use kubernetes to run container images (short for --container-runner=kubernetes)", :type => :boolean
      end

      def resolve_cli_options!(opts)
        resolve_shortcuts(opts)
        resolve_options(opts)
      end

      def resolve_shortcuts(opts)
        opts[:container_runner] ||= "docker" if opts[:docker]
        opts[:container_runner] ||= "podman" if opts[:podman]
        opts[:container_runner] ||= "kubernetes" if opts[:kubernetes]
      end

      def resolve_options(opts)
        runner_options = opts[:container_runner_options].to_h { |opt| opt.split("=", 2) }

        begin
          set_runner(opts[:container_runner], runner_options)
        rescue ArgumentError => e
          Optimist.die(:container_runner, e.message)
        end
      end

      def runner
        @runner || set_runner(nil)
      end

      def set_runner(name_or_instance, options = {})
        @runner =
          case name_or_instance
          when "docker", nil
            Floe::ContainerRunner::Docker.new(options)
          when "podman"
            Floe::ContainerRunner::Podman.new(options)
          when "kubernetes"
            Floe::ContainerRunner::Kubernetes.new(options)
          when Floe::Runner
            name_or_instance
          else
            raise ArgumentError, "container runner must be one of: docker, podman, kubernetes"
          end
      end
    end
  end
end

Floe::Runner.register_scheme("docker", -> { Floe::ContainerRunner.runner })
