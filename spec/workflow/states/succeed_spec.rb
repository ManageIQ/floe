RSpec.describe Floe::Workflow::States::Succeed do
  let(:workflow) { Floe::Workflow.load(GEM_ROOT.join("examples/workflow.asl")) }
  let(:state)    { workflow.states_by_name["SuccessState"] }
  let(:inputs)   { {} }

  it "#terminal_state?" do
    expect(state.terminal_state?).to be true
  end

  it "has a next of nil" do
    next_state, _output = state.run!(inputs)
    expect(next_state).to be nil
  end

  it "has a next of nil" do
    next_state, _output = state.run!(inputs)
    expect(next_state).to be nil
  end
end
