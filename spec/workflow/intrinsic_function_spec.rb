RSpec.describe Floe::Workflow::IntrinsicFunction do
  describe "#initialize" do
    let(:payload) { "States.StringToJson()" }

    it "returns an instance of the intrinsic function" do
      expect(described_class.new(payload)).to be_kind_of(Floe::Workflow::IntrinsicFunctions::States::StringToJson)
    end

    context "with an invalid intrinsic function" do
      let(:payload) { "States.MyFirstFunction()" }

      it "raises an exception for an invalid intrinsic function" do
        expect { described_class.new(payload) }.to raise_error(NotImplementedError)
      end
    end

    context "with no arguments" do
      it "parses args as empty" do
        function = described_class.new(payload)
        expect(function.args).to be_empty
      end
    end

    context "with a string arguments" do
      let(:payload) { "States.StringToJson(foobar)" }

      it "parses the arguments" do
        function = described_class.new(payload)
        expect(function.args).to eq(["foobar"])
      end
    end

    context "with a Path" do
      let(:payload) { "States.StringToJson($.someString)" }

      it "parses the arguments" do
        function = described_class.new(payload)
        expect(function.args.first).to be_kind_of(Floe::Workflow::Path)
      end
    end

    context "with an IntrinsicFunction" do
      let(:payload) { "States.StringToJson(States.StringToJson($.someString))" }

      it "parses the arguments" do
        function = described_class.new(payload)
        expect(function.args.first).to be_kind_of(Floe::Workflow::IntrinsicFunction)
      end
    end
  end
end
