require 'active_support/time'

RSpec.describe Floe::Workflow::Context do
  let(:now) { Time.now.utc }
  let(:ctx) { described_class.new(:input => input) }
  let(:input) { {"x" => "y"}.freeze }
  let(:output) { {"input" => "interim"} }

  describe "#new" do
    it "sets input" do
      expect(ctx.execution["Input"]).to eq(input)
    end
  end

  describe "#started?" do
    it "new context" do
      expect(ctx.started?).to eq(false)
    end

    it "started" do
      ctx.start_next_state!("StartState")

      expect(ctx.started?).to eq(true)
    end
  end

  describe "#running?" do
    it "new context" do
      expect(ctx.running?).to eq(false)
    end

    it "running" do
      ctx.execution["StartTime"] ||= Time.now.utc

      expect(ctx.running?).to eq(true)
    end

    it "ended" do
      ctx.execution["StartTime"] ||= Time.now.utc
      ctx.execution["EndTime"] ||= Time.now.utc

      expect(ctx.running?).to eq(false)
    end
  end

  describe "#start_next_state!" do
    it "sets fields" do
      ctx.start_next_state!("StartState")
      ctx.end_state!(output, "MiddleState")
      ctx.start_next_state!

      expect(ctx.state["Guid"]).to be
      expect(ctx.state_name).to eq("MiddleState")
      expect(ctx.input).to eq(output)
    end
  end

  describe "#start_next_state!" do
    it "sets fields" do
      ctx.start_next_state!("StartState")

      expect(ctx.state["Guid"]).to be
      expect(ctx.state_name).to eq("StartState")
      expect(ctx.input).to eq(input)
    end
  end

  describe "#ended?" do
    it "new context" do
      expect(ctx.ended?).to eq(false)
    end

    it "started" do
      ctx.start_next_state!("StartState")

      expect(ctx.ended?).to eq(false)
    end

    it "ends a non-terminal state" do
      ctx.start_next_state!("StartState")
      ctx.end_state!(input, "MiddleState")

      expect(ctx.ended?).to eq(false)
    end

    it "ends a successful terminal state" do
      ctx.start_next_state!("StartState")
      ctx.end_state!(input)

      expect(ctx.ended?).to eq(true)
    end

    it "ends a failure state" do
      ctx.start_next_state!("StartState")
      ctx.end_state!(input, :error => "Error", :cause => "Issues")

      expect(ctx.ended?).to eq(true)
    end
  end

  describe "#end_state" do
    it "ends a non-termina state" do
      ctx.start_next_state!("StartState")
      ctx.end_state!(input, "MiddleState")

      expect(ctx.next_state).to eq("MiddleState")
      expect(ctx.execution["EndTime"]).to be_nil
    end

    it "ends a successful terminal state" do
      ctx.start_next_state!("StartState")
      ctx.end_state!(input)

      expect(ctx.output).to eq(input)
      expect(ctx.next_state).not_to be
      expect(ctx.execution["EndTime"]).to be_within(1.second).of(now)
    end

    it "ends an error state" do
      ctx.start_next_state!("StartState")
      ctx.end_state!(input, :error => "error", :cause => "issues")

      expect(ctx.output).to eq(input)
      expect(ctx.next_state).not_to be
      expect(ctx.state["Error"]).to eq("error")
      expect(ctx.state["Cause"]).to eq("issues")
      expect(ctx.execution["EndTime"]).to be_within(1.second).of(now)
    end
  end

  describe "#input" do
    it "started" do
      ctx.start_next_state!("FirstState")
      expect(ctx.input).to eq(input)
    end

    it "started second state" do
      ctx.start_next_state!("FirstState")
      ctx.end_state!(output, "SecondState")
      ctx.start_next_state!
      expect(ctx.input).to eq(output)
    end
  end

  describe "#output" do
    it "new context" do
      expect(ctx.output).to eq(nil)
    end

    it "started" do
      ctx.start_next_state!("FirstState")
      expect(ctx.output).to eq(nil)
    end

    it "finished first state" do
      ctx.start_next_state!("FirstState")
      ctx.end_state!(input, "NextState")
      expect(ctx.output).to eq(input)
    end

    it "started second state" do
      ctx.start_next_state!("FirstState")
      ctx.end_state!(input, "NextState")
      ctx.start_next_state!
      expect(ctx.output).to eq(nil)
    end

    it "ended" do
      ctx.start_next_state!("FirstState")
      ctx.end_state!(output)
      expect(ctx.output).to eq(output)
    end
  end

  describe "#state_name" do
    it "started" do
      ctx.start_next_state!("FirstState")

      expect(ctx.state_name).to eq("FirstState")
    end

    it "finished but in the middle" do
      ctx.start_next_state!("FirstState")
      ctx.end_state!(input, "NextState")
      expect(ctx.state_name).to eq("FirstState")
    end

    it "starts a second state" do
      ctx.start_next_state!("FirstState")
      ctx.end_state!(input, "NextState")
      ctx.start_next_state!
      expect(ctx.state_name).to eq("NextState")
    end
  end

  describe "#next_state" do
    it "first context" do
      ctx.state["Name"] = "FirstState"
      ctx.state["NextState"] = "MiddleState"

      expect(ctx.next_state).to eq("MiddleState")
    end
  end

  describe "#status" do
    it "new context" do
      expect(ctx.status).to eq("pending")
    end

    it "started" do
      ctx.start_next_state!("StartState")

      expect(ctx.status).to eq("running")
    end

    it "ended with success" do
      ctx.start_next_state!("StartState")
      ctx.end_state!(output)

      expect(ctx.status).to eq("success")
    end

    it "ended with error" do
      ctx.start_next_state!("StartState")
      ctx.end_state!(output, :error => "Error", :cause => "Cause")

      expect(ctx.status).to eq("failure")
    end
  end
end
