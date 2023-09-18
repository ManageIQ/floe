RSpec.describe Floe::Workflow::States::Succeed do
  let(:workflow) { Floe::Workflow.load(GEM_ROOT.join("examples/workflow.asl"), ctx) }
  let(:ctx)      { Floe::Workflow::Context.new(nil, :input => {}).start_next_state!("SuccessState") }
  let(:state)    { workflow.states_by_name["SuccessState"] }
  let(:input)    { {} }

  it "#end?" do
    expect(state.end?).to be true
  end

  describe "#run!" do
    it "has no next" do
      state.run!(ctx)
      expect(ctx.next_state).to be_nil
      expect(ctx.status).to eq("success")
    end
  end
end
