RSpec.describe Floe::Workflow::States::Pass do
  let(:input)    { {} }
  let(:ctx)      { Floe::Workflow::Context.new(:input => input) }
  let(:state)    { workflow.current_state }
  let(:workflow) { make_workflow(ctx, {"WaitState" => {"Type" => "Wait", "Seconds" => 1, "Next" => "SuccessState"}}) }

  describe "#end?" do
    it "is non-terminal" do
      expect(state.end?).to eq(false)
    end
  end

  describe "#start" do
    it "transitions to the next state" do
      state.start({})

      expect(workflow.context.next_state).to eq("SuccessState")
    end
  end

  describe "#running?" do
    before { workflow.context.state["EnteredTime"] = entered_time.iso8601 }

    context "before the sleep has finished" do
      let(:entered_time) { Time.now.utc }

      it "returns true" do
        expect(state.running?).to be_truthy
      end
    end

    context "after the sleep has finished" do
      let(:entered_time) { Time.now.utc - 10 }

      it "returns false" do
        expect(state.running?).to be_falsey
      end
    end
  end
end
