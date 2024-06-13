RSpec.describe Floe::Workflow::States::Succeed do
  let(:input)    { {} }
  let(:ctx)      { Floe::Workflow::Context.new(:input => input) }
  let(:state)    { workflow.start_workflow.current_state }
  let(:workflow) { make_workflow(ctx, {"SuccessState" => {"Type" => "Succeed"}}) }

  it "#end?" do
    expect(state.end?).to be true
  end

  describe "#run_nonblock!" do
    it "has no next" do
      state.run_nonblock!(ctx)
      expect(ctx.next_state).to eq(nil)
    end
  end
end
