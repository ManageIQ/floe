RSpec.describe Floe::Workflow::States::Map do
  let(:input)    { {} }
  let(:ctx)      { Floe::Workflow::Context.new(:input => input.to_json) }
  let(:state)    { workflow.start_workflow.current_state }
  let(:input)    do
    {
      "ship-date" => "2016-03-14T01:59:00Z",
      "detail"    => {
        "delivery-partner" => "UQS",
        "shipped"          => [
          {"prod" => "R31", "dest-code" => 9511, "quantity" => 1344},
          {"prod" => "S39", "dest-code" => 9511, "quantity" => 40},
          {"prod" => "R31", "dest-code" => 9833, "quantity" => 12},
          {"prod" => "R40", "dest-code" => 9860, "quantity" => 887},
          {"prod" => "R40", "dest-code" => 9511, "quantity" => 1220}
        ]
      }
    }
  end
  let(:workflow) do
    payload = {
      "Validate-All" => {
        "Type"           => "Map",
        "InputPath"      => "$.detail",
        "ItemsPath"      => "$.shipped",
        "MaxConcurrency" => 0,
        "ItemProcessor"  => {
          "StartAt" => "Validate",
          "States"  => {
            "Validate" => {
              "Type"      => "Pass",
              "End"       => true,
              "InputPath" => "$.prod"
            }
          }
        },
        "ResultPath"     => "$.detail.result",
        "End"            => true,
      }
    }
    make_workflow(ctx, payload)
  end

  describe "#initialize" do
    it "raises an InvalidWorkflowError with a missing ItemProcessor" do
      payload = {
        "Validate-All" => {
          "Type" => "Map",
          "End"  => true
        }
      }

      expect { make_workflow(ctx, payload) }
        .to raise_error(Floe::InvalidWorkflowError, "Missing \"InputProcessor\" field in state [Validate-All]")
    end

    it "raises an InvalidWorkflowError with a missing Next and End" do
      payload = {
        "Validate-All" => {
          "Type"          => "Map",
          "ItemProcessor" => {
            "StartAt" => "Validate",
            "States"  => {"Validate" => {"Type" => "Succeed"}}
          }
        }
      }

      expect { make_workflow(ctx, payload) }
        .to raise_error(Floe::InvalidWorkflowError, "States.Validate-All does not have required field \"Next\"")
    end

    it "raises an InvalidWorkflowError if a state in ItemProcessor attempts to transition to a state in the outer workflow" do
      payload = {
        "StartAt" => "MapState",
        "States"  => {
          "MapState"     => {
            "Type"          => "Map",
            "Next"          => "PassState",
            "ItemProcessor" => {
              "StartAt" => "Validate",
              "States"  => {
                "Validate" => {
                  "Type" => "Pass",
                  "Next" => "PassState"
                }
              }
            }
          },
          "PassState"    => {
            "Type" => "Pass",
            "Next" => "SucceedState"
          },
          "SucceedState" => {
            "Type" => "Succeed"
          }
        }
      }

      expect { Floe::Workflow.new(payload, ctx) }
        .to raise_error(Floe::InvalidWorkflowError, "States.Validate field \"Next\" value \"PassState\" is not found in \"States\"")
    end
  end

  it "#end?" do
    expect(state.end?).to be true
  end

  describe "#run_nonblock!" do
    it "has no next" do
      loop while state.run_nonblock!(ctx) != 0
      expect(ctx.next_state).to eq(nil)
    end

    it "sets the context output" do
      loop while state.run_nonblock!(ctx) != 0
      expect(ctx.output.dig("detail", "result")).to eq(%w[R31 S39 R31 R40 R40])
    end

    context "with simple string inputs" do
      let(:input) { {"foo" => "bar", "colors" => ["red", "green", "blue"]} }
      let(:workflow) do
        payload = {
          "Validate-All" => {
            "Type"           => "Map",
            "ItemsPath"      => "$.colors",
            "MaxConcurrency" => 0,
            "ItemProcessor"  => {
              "StartAt" => "Validate",
              "States"  => {
                "Validate" => {
                  "Type" => "Pass",
                  "End"  => true
                }
              }
            },
            "End"            => true,
          }
        }
        make_workflow(ctx, payload)
      end

      it "sets the context output" do
        loop while state.run_nonblock!(ctx) != 0
        expect(ctx.output).to eq(["red", "green", "blue"])
      end
    end
  end
end
