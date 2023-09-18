RSpec.describe Floe::Workflow::States::Pass do
  let(:workflow) { Floe::Workflow.load(GEM_ROOT.join("examples/workflow.asl"), ctx) }
  let(:ctx)      { Floe::Workflow::Context.new(nil, :input => input).start_next_state!("PassState") }
  let(:state)    { workflow.states_by_name["PassState"] }
  let(:input)    { {} }

  describe "#end?" do
    it "is non-terminal" do
      expect(state.end?).to eq(false)
    end
    # TODO: test @end
  end

  describe "#run!" do
    it "sets the result to the result path" do
      next_state, output = state.run!(ctx.input)
      expect(output["result"]).to include(state.result)
      expect(next_state).to eq("WaitState")
    end
  end
end
