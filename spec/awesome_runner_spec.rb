require_relative "../lib/floe/awesome_runner"

RSpec.describe Floe::AwesomeRunner, :uses_awesome_spawn => true do
  let(:subject)        { described_class.new(runner_options) }
  let(:runner_options) { {} }
  let(:container_id)   { SecureRandom.hex }

  # let(:workflow) { make_workflow(ctx, {"State" => {"Type" => "Task", "Resource" => resource, "Parameters" => {"var1.$" => "$.foo.bar"}, "End" => true}}) }

  describe "#run_async!" do
    it "raises an exception without a resource" do
      expect { subject.run_async!(nil) }.to raise_error(ArgumentError, "Invalid resource")
    end

    it "raises an exception for an invalid resource uri" do
      expect { subject.run_async!("arn:abcd:efgh") }.to raise_error(ArgumentError, "Invalid resource")
    end

    it "calls command run with the command name" do
      stub_good_run("ls", :params => [], :env => {}, :output => "file\nlisting\n")

      subject.run_async!("awesome://ls")
    end

    it "passes environment variables to command run" do
      stub_good_run("ls", :params => [], :env => {"FOO" => "BAR"}, :output => "file\nlisting\n")

      subject.run_async!("awesome://ls", {"FOO" => "BAR"})
    end
  end

  # describe "#status!" do
  #   let(:runner_context) { {"container_ref" => container_id} }

  #   it "returns the updated container_state" do
  #     stub_good_run!("ls", :params => ["inspect", container_id], :output => "[{\"State\": {\"Running\": true}}]")

  #     subject.status!(runner_context)

  #     expect(runner_context).to include("container_state" => {"Running" => true})
  #   end
  # end

  describe "#running?" do
    # it "retuns true when running" do
    #   runner_context = {"container_ref" => container_id, "container_state" => {"Running" => true}}
    #   expect(subject.running?(runner_context)).to be_truthy
    # end

    # it "retuns false when not running" do
    #   runner_context = {"container_ref" => container_id, "container_state" => {"Running" => false, "ExitCode" => 0}}
    #   expect(subject.running?(runner_context)).to be_falsey
    # end
  end

  describe "#success?" do
    # it "retuns true when successful" do
    #   runner_context = {"container_ref" => container_id, "container_state" => {"Running" => false, "ExitCode" => 0}}
    #   expect(subject.success?(runner_context)).to be_truthy
    # end

    # it "retuns false when not successful" do
    #   runner_context = {"container_ref" => container_id, "container_state" => {"Running" => false, "ExitCode" => 1}}
    #   expect(subject.success?(runner_context)).to be_falsey
    # end
  end

  describe "#output" do
    let(:runner_context) { {"Output" => ["output1", "output2"]} }

    it "returns log output" do
      expect(subject.output(runner_context)).to eq(["output1", "output2"])
    end
  end

  # describe "#cleanup" do
  # end
end
