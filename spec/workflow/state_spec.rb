RSpec.describe Floe::Workflow::State do
  let(:input)    { {} }
  let(:ctx)      { Floe::Workflow::Context.new(:input => input.to_json) }
  let(:state)    { workflow.start_workflow.current_state }
  # picked a state that doesn't instantly finish
  let(:workflow) { make_workflow(ctx, payload) }
  let(:payload) do
    {
      "WaitState"    => {"Type" => "Wait", "Seconds" => 1, "Next" => "SuccessState"},
      "SuccessState" => {"Type" => "Succeed"}
    }
  end

  describe "#initialize" do
    context "with missing type" do
      let(:payload) { {"FirstState" => {}} }
      it { expect { workflow }.to raise_error(Floe::InvalidWorkflowError, "States.FirstState does not have required field \"Type\"") }
    end

    context "with an invalid type" do
      let(:payload) { {"FirstState" => {"Type" => "Bogus"}} }
      it { expect { workflow }.to raise_error(Floe::InvalidWorkflowError, "States.FirstState field \"Type\" value \"Bogus\" is not valid") }
    end

    context "with a long state name" do
      let(:state_name) { "a" * 200 }
      let(:payload) { {state_name => {"Type" => "Succeed"}} }

      # NOTE: "#{state_name}" # will truncate the state_name per ruby rules
      it "raises an exception for an invalid State name" do
        expect { workflow }.to raise_error(Floe::InvalidWorkflowError, "States field \"Name\" value \"#{state_name}\" must be less than or equal to 80 characters")
      end
    end
  end

  describe "#started?" do
    it "is not started yet" do
      expect(ctx.state_started?).to eq(false)
    end

    it "is started" do
      state.start(ctx)
      expect(ctx.state_started?).to eq(true)
    end

    it "is finished" do
      state.start(ctx)
      state.mark_finished(ctx)

      expect(ctx.state_started?).to eq(true)
    end
  end

  describe "#finished?" do
    it "is not started yet" do
      expect(ctx.state_finished?).to eq(false)
    end

    it "is started" do
      state.start(ctx)
      expect(ctx.state_finished?).to eq(false)
    end

    it "is finished" do
      state.start(ctx)
      state.mark_finished(ctx)

      expect(ctx.state_finished?).to eq(true)
    end
  end
end
