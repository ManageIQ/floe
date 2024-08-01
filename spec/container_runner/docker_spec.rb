RSpec.describe Floe::ContainerRunner::Docker do
  require "securerandom"

  let(:subject)        { described_class.new(runner_options) }
  let(:runner_options) { {} }
  let(:container_id)   { SecureRandom.hex }
  let(:ctx)            { Floe::Workflow::Context.new({}) }

  describe "#run_async!" do
    it "raises an exception without a resource" do
      expect { subject_run_async!(nil) }.to raise_error(ArgumentError, "Invalid resource")
    end

    it "raises an exception for an invalid resource uri" do
      expect { subject_run_async!("arn:abcd:efgh") }.to raise_error(ArgumentError, "Invalid resource")
    end

    it "calls docker run with the image name" do
      stub_good_run!("docker", :params => ["run", :detach, [:name, a_string_starting_with("floe-hello-world-")], "hello-world:latest",], :output => container_id)

      subject_run_async!("docker://hello-world:latest")
    end

    it "passes environment variables to docker run" do
      stub_good_run!("docker", :params => ["run", :detach, [:e, "FOO=BAR"], [:name, a_string_starting_with("floe-hello-world-")], "hello-world:latest"], :output => container_id)

      subject_run_async!("docker://hello-world:latest", {"FOO" => "BAR"})
    end

    it "passes a secrets volume to docker run" do
      stub_good_run!("docker", :params => ["run", :detach, [:e, "FOO=BAR"], [:e, "_CREDENTIALS=/run/secrets"], [:v, a_string_including(":/run/secrets")], [:name, a_string_starting_with("floe-hello-world-")], "hello-world:latest"], :output => container_id)

      subject_run_async!("docker://hello-world:latest", {"FOO" => "BAR"}, {"luggage_password" => "12345"})
    end

    context "with network=host" do
      let(:runner_options) { {"network" => "host"} }

      it "calls docker run with --net host" do
        stub_good_run!("docker", :params => ["run", :detach, [:net, "host"], [:name, a_string_starting_with("floe-hello-world-")], "hello-world:latest"])

        subject_run_async!("docker://hello-world:latest")
      end
    end

    context "with pull-policy=always" do
      let(:runner_options) { {"pull-policy" => "always"} }

      it "calls docker run with --pull always" do
        stub_good_run!("docker", :params => ["run", :detach, [:pull, "always"], [:name, a_string_starting_with("floe-hello-world-")], "hello-world:latest"])

        subject_run_async!("docker://hello-world:latest")
      end
    end
  end

  describe "#status!" do
    it "returns the updated container_state" do
      stub_good_run!("docker", :params => ["inspect", container_id], :output => "[{\"State\": {\"Running\": true}}]")
      runner_context = {"container_ref" => container_id}

      subject.status!(runner_context)

      expect(runner_context).to include("container_state" => {"Running" => true})
    end
  end

  describe "#running?" do
    it "returns true when running" do
      runner_context = {"container_ref" => container_id, "container_state" => {"Running" => true}}
      expect(subject.running?(runner_context)).to be_truthy
    end

    it "returns false when completed" do
      runner_context = {"container_ref" => container_id, "container_state" => {"Running" => false, "ExitCode" => 0}}
      expect(subject.running?(runner_context)).to be_falsey
    end
  end

  describe "#success?" do
    it "returns true when successful" do
      runner_context = {"container_ref" => container_id, "container_state" => {"Running" => false, "ExitCode" => 0}}
      expect(subject.success?(runner_context)).to be_truthy
    end

    it "returns false when unsuccessful" do
      runner_context = {"container_ref" => container_id, "container_state" => {"Running" => false, "ExitCode" => 1}}
      expect(subject.success?(runner_context)).to be_falsey
    end
  end

  describe "#output" do
    let(:runner_context) { {"container_ref" => container_id} }

    it "returns log output" do
      stub_good_run!("docker", :params => ["logs", container_id], :combined_output => true, :output => "hello, world!")
      expect(subject.output(runner_context)).to eq("hello, world!")
    end

    it "raises an exception when getting pod logs fails" do
      stub_bad_run!("docker", :params => ["logs", container_id], :combined_output => true)
      expect { subject.output(runner_context) }.to raise_error(AwesomeSpawn::CommandResultError, /docker exit code: 1/)
    end
  end

  describe "#cleanup" do
    let(:secrets_file) { "/tmp/secretfile" }

    it "deletes the container and secret" do
      stub_good_run!("docker", :params => ["rm", container_id])
      allow(File).to receive(:exist?).and_call_original
      expect(File).to receive(:exist?).with(secrets_file).and_return(true)
      expect(File).to receive(:unlink).with(secrets_file)
      subject.cleanup({"container_ref" => container_id, "secrets_ref" => secrets_file})
    end

    it "doesn't delete the secret_file if not passed" do
      stub_good_run!("docker", :params => ["rm", container_id])
      expect(File).not_to receive(:unlink).with(secrets_file)
      subject.cleanup({"container_ref" => container_id})
    end

    it "deletes the secrets file if deleting the container fails" do
      stub_bad_run!("docker", :params => ["rm", container_id])
      allow(File).to receive(:exist?).and_call_original
      expect(File).to receive(:exist?).with(secrets_file).and_return(true)
      expect(File).to receive(:unlink).with(secrets_file)
      subject.cleanup({"container_ref" => container_id, "secrets_ref" => secrets_file})
    end
  end

  private

  def subject_run_async!(resource, env = {}, secrets = {}, context = ctx)
    subject.run_async!(resource, env, secrets, context)
  end
end
