module Floe
  class Workflow
    class Runner
      module DockerMixin
        def image_name(image)
          image.match(%r{^(?<repository>.+/)?(?<image>.+):(?<tag>.+)$})&.named_captures&.dig("image")
        end

        # 63 is the max kubernetes pod name length
        # -5 for the "floe-" prefix
        # -9 for the random hex suffix and leading hyphen
        MAX_CONTAINER_NAME_SIZE = 63 - 5 - 9

        def container_name(image)
          name = image_name(image)
          raise ArgumentError, "Invalid docker image [#{image}]" if name.nil?

          # Normalize the image name to be used in the container name.
          # This follows RFC 1123 Label names in Kubernetes as they are the most restrictive
          # See https://kubernetes.io/docs/concepts/overview/working-with-objects/names/#dns-label-names
          # and https://github.com/kubernetes/kubernetes/blob/952a9cb0/staging/src/k8s.io/apimachinery/pkg/util/validation/validation.go#L178-L184
          #
          # This does not follow the leading and trailing character restriction because we will embed it
          # below with a prefix and suffix that already conform to the RFC.
          normalized_name = name.downcase.gsub(/[^a-z0-9-]/, "-")[0, MAX_CONTAINER_NAME_SIZE]

          "floe-#{normalized_name}-#{SecureRandom.hex(4)}"
        end
      end
    end
  end
end
