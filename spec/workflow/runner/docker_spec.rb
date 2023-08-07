RSpec.describe Floe::Workflow::Runner::Docker do
  let(:subject)        { described_class.new(runner_options) }
  let(:runner_options) { {} }

  describe "#run!" do
    it "raises an exception without a resource" do
      expect { subject.run!(nil) }.to raise_error(ArgumentError, "Invalid resource")
    end

    it "raises an exception for an invalid resource uri" do
      expect { subject.run!("arn:abcd:efgh") }.to raise_error(ArgumentError, "Invalid resource")
    end

    it "calls docker run with the image name" do
      stub_good_run!("docker", :params => ["run", :rm, "hello-world:latest"])

      subject.run!("docker://hello-world:latest")
    end

    it "passes environment variables to docker run" do
      stub_good_run!("docker", :params => ["run", :rm, [:e, "FOO=BAR"], "hello-world:latest"])

      subject.run!("docker://hello-world:latest", {"FOO" => "BAR"})
    end

    it "passes a secrets volume to docker run" do
      stub_good_run!("docker", :params => ["run", :rm, [:e, "FOO=BAR"], [:e, "SECRETS=/run/secrets"], [:v, a_string_including(":/run/secrets")], "hello-world:latest"])

      subject.run!("docker://hello-world:latest", {"FOO" => "BAR"}, {"luggage_password" => "12345"})
    end

    context "with network=host" do
      let(:runner_options) { {"network" => "host"} }

      it "calls docker run with --net host" do
        stub_good_run!("docker", :params => ["run", :rm, [:net, "host"], "hello-world:latest"])

        subject.run!("docker://hello-world:latest")
      end
    end
  end
end
