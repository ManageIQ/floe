RSpec.describe Floe::Workflow::States::Choice do
  let(:workflow) { Floe::Workflow.load(GEM_ROOT.join("examples/workflow.asl")) }
  let(:ctx)      { Floe::Workflow::Context.new(nil, :input => input).start_next_state!("ChoiceState") }
  let(:state)    { workflow.states_by_name["ChoiceState"] }
  let(:input)    { {} }

  it "#end?" do
    expect(state.end?).to eq(false)
  end

  describe "#run!" do
    context "with a missing variable" do
      it "raises an exception" do
        expect { state.run!(ctx.input) }.to raise_error(RuntimeError, "No such variable [$.foo]")
      end
    end

    context "with an input value matching a condition" do
      let(:input) { {"foo" => 1} }

      it "returns the next state" do
        state.run!(ctx.input)
        expect(ctx.next_state).to eq("FirstMatchState")
        expect(ctx.status).to eq("running")
      end
    end

    context "with an input value not matching any condition" do
      let(:input) { {"foo" => 4} }

      it "returns the default state" do
        state.run!(ctx.input)
        expect(ctx.next_state).to eq("FailState")
        expect(ctx.status).to eq("running")
      end
    end
  end
end
