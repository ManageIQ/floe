RSpec.describe Floe::Workflow::Runner::Kubernetes do
  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('KUBECONFIG', nil).and_return(nil)
  end

  let(:subject)        { described_class.new(runner_options) }
  let(:runner_options) { {"server" => "https://kubernetes.local:6443", "token" => "my-token"} }
  let(:kubeclient) { double("Kubeclient::Client") }

  before do
    require "kubeclient"

    allow(Kubeclient::Client).to receive(:new).and_return(kubeclient)
    allow(kubeclient).to receive(:discover)
  end

  describe "#run_async!" do
    it "raises an exception without a resource" do
      expect { subject.run_async!(nil) }.to raise_error(ArgumentError, "Invalid resource")
    end

    it "raises an exception for an invalid resource uri" do
      expect { subject.run_async!("arn:abcd:efgh") }.to raise_error(ArgumentError, "Invalid resource")
    end

    it "calls kubectl run with the image name" do
      expected_pod_spec = hash_including(
        :kind       => "Pod",
        :apiVersion => "v1",
        :metadata   => {
          :name      => a_string_starting_with("floe-hello-world-"),
          :namespace => "default"
        },
        :spec       => hash_including(
          :containers => [
            hash_including(
              :name  => "floe-hello-world",
              :image => "hello-world:latest"
            )
          ]
        )
      )
      stub_kubernetes_run(:spec => expected_pod_spec, :status => false, :cleanup => false)

      subject.run_async!("docker://hello-world:latest")
    end

    it "calls kubectl run with an image name <= 63 characters" do
      expected_pod_spec = hash_including(
        :kind       => "Pod",
        :apiVersion => "v1",
        :metadata   => {
          :name      => a_string_matching(/^floe-this-is-a-very-long-image-name-way-longer-than-sh-\h{8}$/).and(is_a_valid_kube_name),
          :namespace => "default"
        },
        :spec       => hash_including(
          :containers => [
            hash_including(
              :name  => eq("floe-this-is-a-very-long-image-name-way-longer-than-sh").and(is_a_valid_kube_name),
              :image => "this-is-a-very-long-image-name-way-longer-than-should-be-allowed:latest"
            )
          ]
        )
      )

      stub_kubernetes_run(:spec => expected_pod_spec, :status => false, :cleanup => false)

      subject.run_async!("docker://this-is-a-very-long-image-name-way-longer-than-should-be-allowed:latest")
    end

    it "calls kubectl run with an image name that has characters that would be invalid in a pod name" do
      expected_pod_spec = hash_including(
        :kind       => "Pod",
        :apiVersion => "v1",
        :metadata   => {
          :name      => a_string_matching(/^floe-a-b-c-0--1--2-\h{8}$/).and(is_a_valid_kube_name),
          :namespace => "default"
        },
        :spec       => hash_including(
          :containers => [
            hash_including(
              :name  => eq("floe-a-b-c-0--1--2").and(is_a_valid_kube_name),
              :image => "a.b-c_0--1__2:latest"
            )
          ]
        )
      )

      stub_kubernetes_run(:spec => expected_pod_spec, :status => false, :cleanup => false)

      subject.run_async!("docker://a.b-c_0--1__2:latest")
    end

    it "doesn't create a secret if Credentials is nil" do
      expected_pod_spec = hash_including(:kind => "Pod", :apiVersion => "v1", :metadata => {:name => a_string_starting_with("floe-hello-world-"), :namespace => "default"})

      expect(subject).not_to receive(:create_secret!)
      stub_kubernetes_run(:spec => expected_pod_spec, :status => false, :cleanup => false)

      subject.run_async!("docker://hello-world:latest", {}, nil)
    end

    it "passes environment variables to kubectl run" do
      expected_pod_spec = hash_including(
        :spec => hash_including(
          :containers => [hash_including(:env => [{:name => "FOO", :value => "BAR"}])]
        )
      )

      stub_kubernetes_run(:spec => expected_pod_spec, :status => false, :cleanup => false)

      subject.run_async!("docker://hello-world:latest", {"FOO" => "BAR"})
    end

    it "passes integer environment variables to kubectl run as strings" do
      expected_pod_spec = hash_including(
        :spec => hash_including(
          :containers => [hash_including(:env => [{:name => "FOO", :value => "1"}])]
        )
      )

      stub_kubernetes_run(:spec => expected_pod_spec, :status => false, :cleanup => false)

      subject.run_async!("docker://hello-world:latest", {"FOO" => 1})
    end

    it "passes a secrets volume to kubectl run" do
      expected_pod_spec = hash_including(
        :kind       => "Pod",
        :apiVersion => "v1",
        :metadata   => {:name => a_string_starting_with("floe-hello-world-"), :namespace => "default"},
        :spec       => hash_including(
          :volumes    => [{:name => "secret-volume", :secret => {:secretName => anything}}],
          :containers => [
            hash_including(
              :env          => [
                {:name => "FOO",          :value => "BAR"},
                {:name => "_CREDENTIALS", :value => a_string_including("/run/secrets/")}
              ],
              :volumeMounts => [
                {
                  :mountPath => a_string_including("/run/secrets/"),
                  :name      => "secret-volume",
                  :readOnly  => true
                }
              ]
            )
          ]
        )
      )

      expect(kubeclient).to receive(:create_secret).with(hash_including(:kind => "Secret", :type => "Opaque"))
      stub_kubernetes_run(:spec => expected_pod_spec, :status => false, :cleanup => false)

      subject.run_async!("docker://hello-world:latest", {"FOO" => "BAR"}, {"luggage_password" => "12345"})
    end

    it "cleans up secrets if running the pod fails" do
      expect(kubeclient).to receive(:create_secret).with(hash_including(:kind => "Secret", :type => "Opaque"))
      stub_kubernetes_bad_run
      expect(kubeclient).to receive(:delete_secret)
      expect(subject.run_async!("docker://hello-world:latest", {"FOO" => "BAR"}, {"luggage_password" => "12345"})).to eq({"Error" => "States.TaskFailed", "Cause" => "HTTP status code 403, Forbidden"})
    end

    context "with an alternate namespace" do
      let(:namespace)      { "my-project" }
      let(:runner_options) { {"server" => "https://kubernetes.local:6443", "token" => "my-token", "namespace" => namespace} }

      it "calls kubectl run with the image name" do
        expected_pod_spec = hash_including(:kind => "Pod", :apiVersion => "v1", :metadata => {:name => a_string_starting_with("floe-hello-world-"), :namespace => namespace})

        stub_kubernetes_run(:spec => expected_pod_spec, :namespace => namespace, :status => false, :cleanup => false)

        subject.run_async!("docker://hello-world:latest")
      end
    end

    context "with a task service account name" do
      let(:task_service_account) { "my-service-account" }
      let(:runner_options) { {"server" => "https://kubernetes.local:6443", "token" => "my-token", "task_service_account" => task_service_account} }

      it "calls kubectl run with the service account" do
        expected_pod_spec = hash_including(:kind => "Pod", :apiVersion => "v1", :spec => hash_including(:serviceAccountName => task_service_account))

        stub_kubernetes_run(:spec => expected_pod_spec, :status => false, :cleanup => false)

        subject.run_async!("docker://hello-world:latest")
      end
    end

    context "with pull-policy=Always" do
      let(:runner_options) { {"server" => "https://kubernetes.local:6443", "token" => "my-token", "pull-policy" => "Always"} }

      it "creates the pod spec with imagePullPolicy=Always" do
        expected_pod_spec = hash_including(:kind => "Pod", :apiVersion => "v1", :spec => hash_including(:imagePullPolicy => "Always"))

        stub_kubernetes_run(:spec => expected_pod_spec, :status => false, :cleanup => false)

        subject.run_async!("docker://hello-world:latest")
      end
    end

    context "without a kubeconfig file or server+token" do
      let(:runner_options) { {} }

      before do
        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:exist?).with(File.join(Dir.home, ".kube", "config")).and_return(false)
      end

      it "raises an exception" do
        expect { subject.run_async!("docker://hello-world:latest") }.to raise_error(ArgumentError, /Missing connections options/)
      end
    end

    context "with a kubeconfig file" do
      let(:kubeconfig_path) { File.join(Dir.home, ".kube", "config") }
      let(:kubeconfig) do
        {
          "apiVersion"      => "v1",
          "clusters"        => [
            {
              "cluster" => {"server" => "https://kubernetes.local:6443"},
              "name"    => "default"
            }
          ],
          "contexts"        => [
            {"context" => {"cluster" => "default", "user" => "default"}, "name" => "default"},
            {"context" => {"cluster" => "default", "user" => "foo"},     "name" => "foo"}
          ],
          "current-context" => "default",
          "kind"            => "Config",
          "preferences"     => {},
          "users"           => [
            {
              "name" => "default",
              "user" => {
                "token" => "my-token"
              }
            },
            {
              "name" => "foo",
              "user" => {
                "token" => "foo"
              }
            }
          ]
        }.to_yaml
      end

      before do
        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:read).and_call_original

        allow(File).to receive(:exist?).with(kubeconfig_path).and_return(true)
        allow(File).to receive(:read).with(kubeconfig_path).and_return(kubeconfig)
      end

      context "with no runner options passed" do
        let(:runner_options) { {} }

        it "uses the kubeconfig values" do
          expect(Kubeclient::Client).to receive(:new).with("https://kubernetes.local:6443", "v1", :ssl_options => {:verify_ssl => OpenSSL::SSL::VERIFY_PEER}, :auth_options => {:bearer_token => "my-token"}).and_return(kubeclient)
          stub_kubernetes_run(:status => false, :cleanup => false)

          subject.run_async!("docker://hello-world:latest")
        end
      end

      context "with server+token passed as runner options" do
        let(:runner_options) { {"server" => "https://my-other-kubernetes.local:6443", "token" => "my-other-token"} }

        it "prefers the provided options values over the kubeconfig file" do
          expect(Kubeclient::Client).to receive(:new).with("https://my-other-kubernetes.local:6443", "v1", :ssl_options => {:verify_ssl => OpenSSL::SSL::VERIFY_PEER}, :auth_options => {:bearer_token => "my-other-token"})
          stub_kubernetes_run(:status => false, :cleanup => false)

          subject.run_async!("docker://hello-world:latest")
        end
      end

      context "with an alternate kubeconfig file passed as an option" do
        let(:kubeconfig_path) { "/etc/kube/config" }
        let(:runner_options)  { {"kubeconfig" => kubeconfig_path} }

        it "uses the kubeconfig values" do
          expect(Kubeclient::Client).to receive(:new).with("https://kubernetes.local:6443", "v1", :ssl_options => {:verify_ssl => OpenSSL::SSL::VERIFY_PEER}, :auth_options => {:bearer_token => "my-token"})
          stub_kubernetes_run(:status => false, :cleanup => false)

          subject.run_async!("docker://hello-world:latest")
        end
      end

      context "with an alternate context passed" do
        let(:runner_options) { {"kubeconfig_context" => "foo"} }

        it "uses the values from the kubeconfig context" do
          expect(Kubeclient::Client).to receive(:new).with("https://kubernetes.local:6443", "v1", :ssl_options => {:verify_ssl => OpenSSL::SSL::VERIFY_PEER}, :auth_options => {:bearer_token => "foo"})
          stub_kubernetes_run(:status => false, :cleanup => false)

          subject.run_async!("docker://hello-world:latest")
        end
      end
    end

    context "with a token" do
      let(:token)          { "my-token" }
      let(:runner_options) { {"server" => "https://kubernetes.local:6443", "token" => token} }

      it "calls kubectl run with the image name" do
        expect(Kubeclient::Client).to receive(:new).with("https://kubernetes.local:6443", "v1", :ssl_options => {:verify_ssl => OpenSSL::SSL::VERIFY_PEER}, :auth_options => {:bearer_token => token}).and_return(kubeclient)
        stub_kubernetes_run(:status => false, :cleanup => false)

        subject.run_async!("docker://hello-world:latest")
      end
    end

    context "with a token file" do
      let(:token)          { "my-token" }
      let(:token_file)     { "/path/to/my-token" }
      let(:runner_options) { {"server" => "https://kubernetes.local:6443", "token_file" => token_file} }

      it "calls kubectl run with the image name" do
        allow(File).to receive(:read).and_call_original
        expect(File).to receive(:read).with(token_file).and_return(token)

        expect(Kubeclient::Client).to receive(:new).with("https://kubernetes.local:6443", "v1", :ssl_options => {:verify_ssl => OpenSSL::SSL::VERIFY_PEER}, :auth_options => {:bearer_token => token}).and_return(kubeclient)
        stub_kubernetes_run(:status => false, :cleanup => false)

        subject.run_async!("docker://hello-world:latest")
      end
    end
  end

  describe "#status!" do
    let(:runner_context) { {"container_ref" => "my-pod"} }

    it "updates the runner_context with container_state" do
      allow(kubeclient).to receive(:get_pod).and_return({"status" => {"phase" => "Pending"}})
      subject.status!(runner_context)
      expect(runner_context).to include("container_state" => {"phase" => "Pending"})
    end

    it "raises an exception when getting pod info fails" do
      allow(kubeclient).to receive(:get_pod).and_raise(Kubeclient::ResourceNotFoundError.new(404, "Resource Not Found", {}))
      expect { subject.status!(runner_context) }.to raise_error(Kubeclient::ResourceNotFoundError, /Resource Not Found/)
    end
  end

  describe "#running?" do
    it "returns true when phase is Pending" do
      runner_context = {"container_ref" => "my-pod", "container_state" => {"phase" => "Pending"}}
      expect(subject.running?(runner_context)).to be_truthy
    end

    it "returns true when phase is Running" do
      runner_context = {"container_ref" => "my-pod", "container_state" => {"phase" => "Running"}}
      expect(subject.running?(runner_context)).to be_truthy
    end

    it "returns false when phase is Succeeded" do
      runner_context = {"container_ref" => "my-pod", "container_state" => {"phase" => "Succeeded"}}
      expect(subject.running?(runner_context)).to be_falsey
    end

    it "returns false when there is an ErrImagePull" do
      runner_context = {"container_ref" => "my-pod", "container_state" => {"phase" => "Pending", "containerStatuses" => [{"name" => "my-container", "state" => {"waiting" => {"reason" => "ErrImagePull", "message" => "rpc error: code = Unknown desc = failed to pull and unpack image"}}}]}}
      expect(subject.running?(runner_context)).to be_falsey
    end

    it "returns false when there is an ImagePullBackOff" do
      runner_context = {"container_ref" => "my-pod", "container_state" => {"phase" => "Pending", "containerStatuses" => [{"name" => "my-container", "state" => {"waiting" => {"reason" => "ImagePullBackOff", "message" => "Back-off pulling image"}}}]}}
      expect(subject.running?(runner_context)).to be_falsey
    end
  end

  describe "#success?" do
    it "returns false when phase is Pending" do
      runner_context = {"container_ref" => "my-pod", "container_state" => {"phase" => "Pending"}}
      expect(subject.success?(runner_context)).to be_falsey
    end

    it "returns false when phase is Running" do
      runner_context = {"container_ref" => "my-pod", "container_state" => {"phase" => "Running"}}
      expect(subject.success?(runner_context)).to be_falsey
    end

    it "returns true when phase is Succeeded" do
      runner_context = {"container_ref" => "my-pod", "container_state" => {"phase" => "Succeeded"}}
      expect(subject.success?(runner_context)).to be_truthy
    end

    it "returns false when there is an ErrImagePull" do
      runner_context = {"container_ref" => "my-pod", "container_state" => {"phase" => "Pending", "containerStatuses" => [{"name" => "my-container", "state" => {"waiting" => {"reason" => "ErrImagePull", "message" => "rpc error: code = Unknown desc = failed to pull and unpack image"}}}]}}
      expect(subject.success?(runner_context)).to be_falsey
    end

    it "returns false when there is an ImagePullBackOff" do
      runner_context = {"container_ref" => "my-pod", "container_state" => {"phase" => "Pending", "containerStatuses" => [{"name" => "my-container", "state" => {"waiting" => {"reason" => "ImagePullBackOff", "message" => "Back-off pulling image"}}}]}}
      expect(subject.success?(runner_context)).to be_falsey
    end
  end

  describe "#output" do
    let(:runner_context) { {"container_ref" => "my-pod"} }

    it "returns log output" do
      expect(kubeclient).to receive(:get_pod_log).with("my-pod", "default").and_return(RestClient::Response.new("hello, world!"))
      expect(subject.output(runner_context)).to eq("hello, world!")
    end

    it "raises an exception when getting pod logs fails" do
      allow(kubeclient).to receive(:get_pod_log).and_raise(Kubeclient::ResourceNotFoundError.new(404, "Resource Not Found", {}))
      expect { subject.output(runner_context) }.to raise_error(Kubeclient::ResourceNotFoundError, /Resource Not Found/)
    end

    it "returns an error when  there is an ErrImagePull" do
      runner_context = {"container_ref" => "my-pod", "container_state" => {"phase" => "Pending", "containerStatuses" => [{"name" => "my-container", "state" => {"waiting" => {"reason" => "ErrImagePull", "message" => "rpc error: code = Unknown desc = failed to pull and unpack image"}}}]}}
      expect(subject.output(runner_context)).to eq({"Error" => "ErrImagePull", "Cause" => "rpc error: code = Unknown desc = failed to pull and unpack image"})
    end

    it "returns an error when  there is an ImagePullBackOff" do
      runner_context = {"container_ref" => "my-pod", "container_state" => {"phase" => "Pending", "containerStatuses" => [{"name" => "my-container", "state" => {"waiting" => {"reason" => "ImagePullBackOff", "message" => "Back-off pulling image"}}}]}}
      expect(subject.output(runner_context)).to eq({"Error" => "ImagePullBackOff", "Cause" => "Back-off pulling image"})
    end
  end

  describe "#cleanup" do
    it "deletes pods and secrets" do
      expect(kubeclient).to receive(:delete_pod).with("my-pod", "default")
      expect(kubeclient).to receive(:delete_secret).with("my-secret", "default")

      subject.cleanup({"container_ref" => "my-pod", "secrets_ref" => "my-secret"})
    end

    it "doesn't delete secret if none passed in" do
      expect(kubeclient).to receive(:delete_pod).with("my-pod", "default")
      expect(kubeclient).not_to receive(:delete_secret)

      subject.cleanup({"container_ref" => "my-pod"})
    end

    it "deletes secret if pod deletion fails" do
      expect(kubeclient).to receive(:delete_pod).with("my-pod", "default").and_raise(Kubeclient::ResourceNotFoundError.new(404, "Resource Not Found", {}))
      expect(kubeclient).to receive(:delete_secret).with("my-secret", "default")

      subject.cleanup({"container_ref" => "my-pod", "secrets_ref" => "my-secret"})
    end
  end

  def stub_kubernetes_run(spec: nil, namespace: "default", status: 1, cleanup: true)
    # start
    if spec
      expect(kubeclient).to receive(:create_pod).with(spec)
    else
      expect(kubeclient).to receive(:create_pod)
    end

    # run
    if status && status > 0
      (status - 1).times do
        expect(kubeclient).to receive(:get_pod).with(a_string_starting_with("floe-hello-world-"), namespace).and_return({"status" => {"phase" => "Running"}})
      end
      expect(kubeclient).to receive(:get_pod).with(a_string_starting_with("floe-hello-world-"), namespace).and_return({"status" => {"phase" => "Succeeded"}})
      expect(kubeclient).to receive(:get_pod_log).with(a_string_starting_with("floe-hello-world-"), namespace).and_return(RestClient::Response.new("hello, world!"))
    end

    if cleanup
      expect(kubeclient).to receive(:delete_pod).with(a_string_starting_with("floe-hello-world-"), namespace)
    end
  end

  def stub_kubernetes_bad_run
    expect(kubeclient).to receive(:create_pod).and_raise(Kubeclient::HttpError.new(403, "Forbidden", {}))
    expect(kubeclient).to receive(:delete_pod).with(a_string_starting_with("floe-hello-world-"), "default").and_raise(Kubeclient::HttpError.new(404, "Not Found", {}))
  end

  def is_a_valid_kube_name
    # See https://kubernetes.io/docs/concepts/overview/working-with-objects/names/#dns-label-names
    # and https://github.com/kubernetes/kubernetes/blob/952a9cb0/staging/src/k8s.io/apimachinery/pkg/util/validation/validation.go#L178-L184
    a_string_matching(/^[a-z0-9]([-a-z0-9]*[a-z0-9])?$/).and(a_string_matching(/^.{0,63}$/))
  end
end
