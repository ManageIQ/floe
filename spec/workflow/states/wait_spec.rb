RSpec.describe Floe::Workflow::States::Pass do
 let(:workflow) { Floe::Workflow.load(GEM_ROOT.join("examples/workflow.asl")) }
  let(:ctx)      { Floe::Workflow::Context.new(nil, :input => input).start_next_state!("WaitState") }
  let(:state)    { workflow.states_by_name["WaitState"] }
  let(:input)    { {} }

  describe "#end?" do
    it "is non-terminal" do
      expect(state.end?).to eq(false)
    end
  end

  describe "#run!" do
    it "sleeps for the requested amount of time" do
      expect(state).to receive(:sleep).with(state.seconds)

      state.run!(ctx)
    end

    it "transitions to the next state" do
      # skip the actual sleep
      expect(state).to receive(:sleep).with(state.seconds)

      state.run!(ctx)

      expect(ctx.next_state).to eq("NextState")
      expect(ctx.status).to eq("running")
    end
  end
end
