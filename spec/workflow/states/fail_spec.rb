RSpec.describe Floe::Workflow::States::Fail do
  let(:workflow) { Floe::Workflow.load(GEM_ROOT.join("examples/workflow.asl"), ctx) }
  let(:ctx)      { Floe::Workflow::Context.new(nil, :input => {}).start_next_state!("FailState") }
  let(:state)    { workflow.states_by_name["FailState"] }
  let(:input)    { {} }

  it "#end?" do
    expect(state.end?).to be true
  end

  it "#run!" do
    state.run!(ctx)
    ctx.next_state
    ctx.status
    expect(ctx.next_state).to eq(nil)
    expect(ctx.status).to eq("failure")
  end
end
