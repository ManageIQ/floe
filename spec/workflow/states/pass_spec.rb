RSpec.describe Floe::Workflow::States::Pass do
  let(:input)    { {} }
  let(:ctx)      { Floe::Workflow::Context.new(:input => input) }
  let(:state)    { workflow.start_workflow.current_state }
  let(:workflow) { make_workflow(ctx, payload) }
  let(:payload)  do
    {
      "PassState"    => {
        "Type"       => "Pass",
        "Result"     => {
          "foo" => "bar",
          "bar" => "baz"
        },
        "ResultPath" => "$.result",
        "Next"       => "SuccessState"
      },
      "SuccessState" => {"Type" => "Succeed"}
    }
  end

  describe "#end?" do
    it "is non-terminal" do
      expect(state.end?).to eq(false)
    end
  end

  describe "#run_nonblock!" do
    it "sets the result to the result path" do
      state.run_nonblock!(ctx)
      expect(ctx.output["result"]).to include({"foo" => "bar", "bar" => "baz"})
      expect(ctx.next_state).to eq("SuccessState")
    end

    context "with a ResultPath setting a Credential" do
      let(:payload) do
        {
          "PassState"    => {
            "Type"       => "Pass",
            "Result"     => {
              "user"     => "luggage",
              "password" => "1234"
            },
            "ResultPath" => "$.Credentials",
            "Next"       => "SuccessState"
          },
          "SuccessState" => {"Type" => "Succeed"}
        }
      end

      it "sets the result in Credentials" do
        state.run_nonblock!(ctx)
        expect(ctx.credentials).to include({"user" => "luggage", "password" => "1234"})
        expect(ctx.next_state).to eq("SuccessState")
      end
    end

    # https://states-language.net/#inputoutput-processing-examples
    context "with 2 blocks" do
      let(:payload) do
        {
          "First"   => {
            "Type"       => "Pass",
            "Result"     => {
              "title"   => "Numbers to add",
              "numbers" => {"val1" => 3, "val2" => 4}
            },
            "ResultPath" => "$",
            "Next"       => "Second"
          },
          "Second"  => {
            "Type"       => "Pass",
            "Result"     => 7,
            "InputPath"  => "$.numbers",
            "ResultPath" => "$.sum",
            "Next"       => "Success"
          },
          "Success" => {
            "Type" => "Succeed"
          }
        }
      end

      it "Uses raw input" do
        workflow.run_nonblock
        expect(ctx.output).to eq(
          "title"   => "Numbers to add",
          "numbers" => {"val1" => 3, "val2" => 4},
          "sum"     => 7
        )
      end
    end
  end
end
