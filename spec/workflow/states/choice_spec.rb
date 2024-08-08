RSpec.describe Floe::Workflow::States::Choice do
  let(:input)    { {} }
  let(:ctx)      { Floe::Workflow::Context.new(:input => input.to_json) }
  let(:state)    { workflow.start_workflow.current_state }
  let(:workflow) { make_workflow(ctx, payload) }
  let(:choices) do
    [
      {"Variable" => "$.foo", "NumericEquals" => 1, "Next" => "FirstMatchState"},
      {"Variable" => "$.foo", "NumericEquals" => 2, "Next" => "SecondMatchState"},
    ]
  end

  let(:payload) do
    {
      "Choice1"          => {"Type" => "Choice", "Choices" => choices, "Default" => "DefaultState"},
      "FirstMatchState"  => {"Type" => "Succeed"},
      "SecondMatchState" => {"Type" => "Succeed"},
      "DefaultState"     => {"Type" => "Succeed"}
    }
  end

  context "with missing Choices" do
    let(:payload) { {"Choice1" => {"Type" => "Choice", "Default" => "DefaultState"}, "DefaultState" => {"type" => "Succeed"}} }
    it { expect { workflow }.to raise_error(Floe::InvalidWorkflowError, "States.Choice1 does not have required field \"Choices\"") }
  end

  context "with non-array Choices" do
    let(:choices) { {} }
    it { expect { workflow }.to raise_error(Floe::InvalidWorkflowError, "States.Choice1 field \"Choices\" must be a non-empty array") }
  end

  context "with an empty Choices array" do
    let(:choices) { [] }
    it { expect { workflow }.to raise_error(Floe::InvalidWorkflowError, "States.Choice1 field \"Choices\" must be a non-empty array") }
  end

  context "with an invalid Default" do
    let(:payload) { {"Choice1" => {"Type" => "Choice", "Choices" => choices, "Default" => "MissingState"}, "FirstMatchState" => {"Type" => "Succeed"}, "SecondMatchState" => {"Type" => "Succeed"}} }
    it { expect { workflow }.to raise_error(Floe::InvalidWorkflowError, "States.Choice1 field \"Default\" value \"MissingState\" is not found in \"States\"") }
  end

  it "#end?" do
    expect(state.end?).to eq(false)
  end

  describe "#run_nonblock!" do
    context "with a missing variable" do
      it "shows error" do
        workflow.run_nonblock
        expect(ctx.failed?).to eq(true)
        expect(ctx.output).to eq(
          {
            "Cause" => "Path [$.foo] references an invalid value",
            "Error" => "States.Runtime"
          }
        )
      end
    end

    context "with an input value matching a condition" do
      let(:input) { {"foo" => 1} }

      it "returns the next state" do
        state.run_nonblock!(ctx)
        expect(ctx.next_state).to eq("FirstMatchState")
      end
    end

    context "with an input value not matching any condition" do
      let(:input) { {"foo" => 4} }

      it "returns the default state" do
        state.run_nonblock!(ctx)
        expect(ctx.next_state).to eq("DefaultState")
      end
    end

    context "with no default" do
      let(:payload) do
        {
          "Choice1"          => {"Type" => "Choice", "Choices" => choices},
          "FirstMatchState"  => {"Type" => "Succeed"},
          "SecondMatchState" => {"Type" => "Succeed"}
        }
      end

      context "with an input value matching a condition" do
        let(:input) { {"foo" => 1} }

        it "returns the next state" do
          state.run_nonblock!(ctx)
          expect(ctx.next_state).to eq("FirstMatchState")
        end
      end

      context "with an input value not matching a condition" do
        let(:input) { {"foo" => 3} }

        it "throws error when not found" do
          workflow.run_nonblock
          expect(ctx.failed?).to eq(true)
          expect(ctx.output["Error"]).to eq("States.NoChoiceMatched")
          expect(ctx.output["Cause"]).to eq("States.Choice1 field \"Default\" not defined and no match found")
        end
      end
    end
  end
end
