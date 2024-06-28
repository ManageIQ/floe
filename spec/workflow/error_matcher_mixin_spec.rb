RSpec.describe Floe::Workflow::ErrorMatcherMixin do
  let(:input) { {} }
  let(:ctx) { Floe::Workflow::Context.new(:input => input) }
  let(:resource) { "docker://hello-world:latest" }
  # we could have used catchers
  let(:retriers) { {"ErrorEquals" => ["States.ALL"]} }
  let(:catchers) { retriers.map { |rt| rt.merge("Next" => "SuccessState") } }
  let(:workflow) do
    make_workflow(
      ctx, {
        "State"        => {
          "Type"     => "Task",
          "Resource" => resource,
          "Retry"    => retriers,
          "Catcher"  => catchers,
          "Next"     => "SuccessState"
        }.compact,
        "FirstState"   => {"Type" => "Succeed"},
        "SuccessState" => {"Type" => "Succeed"},
        "FailState"    => {"Type" => "Succeed"}
      }
    )
  end

  let(:subject) { workflow.start_workflow.current_state.retry.first }

  describe "#match_error?" do
    context "with no ErrorEquals" do
      let(:retriers) { [{}] }
      it { expect { subject }.to raise_error(Floe::InvalidWorkflowError, "States.State.Retry.0 does not have required field \"ErrorEquals\"") }
    end

    context "with empty ErrorEquals" do
      let(:retriers) { [{"ErrorEquals" => []}] }
      it { expect { subject }.to raise_error(Floe::InvalidWorkflowError, "States.State.Retry.0 does not have required field \"ErrorEquals\"") }
    end

    context "when matching an error" do
      let(:retriers) { [{"ErrorEquals" => ["States.Permissions"]}] }
      it "matches the error" do
        expect(subject.match_error?("States.Permissions")).to eq(true)
      end

      it "fails to match other errors" do
        expect(subject.match_error?("States.Timeout")).to eq(false)
      end
    end

    context "when matching States.ALL" do
      let(:retriers) { [{"ErrorEquals" => ["States.ALL"]}] }
      it "matches other exceptions" do
        expect(subject.match_error?("States.Permissions")).to eq(true)
      end

      it "does not match States.Runtime" do
        expect(subject.match_error?("States.Runtime")).to eq(false)
      end
    end

    context "when matching States.Timeout" do
      let(:retriers) { [{"ErrorEquals" => ["States.Timeout"]}] }
      it "matches HearbeatTimeout" do
        expect(subject.match_error?("States.HeartbeatTimeout")).to eq(true)
      end

      it "fails to match other errors" do
        expect(subject.match_error?("States.Permissions")).to eq(false)
      end
    end
  end
end
