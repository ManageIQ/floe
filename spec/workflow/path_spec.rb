RSpec.describe Floe::Workflow::Path do
  it "raises an exception if the payload isn't a string" do
    expect { described_class.new(nil) }.to raise_error(Floe::InvalidWorkflowError, "Path [] must be a string")
    expect { described_class.new(0) }.to raise_error(Floe::InvalidWorkflowError, "Path [0] must be a string")
  end

  it "raises an exception if the first character isn't a $" do
    expect { described_class.new("foo") }.to raise_error(Floe::InvalidWorkflowError, "Path [foo] must start with \"$\"")
  end

  describe "#value" do
    context "referencing the global context" do
      it "with a missing value" do
        expect { described_class.new("$$.foo").value({}, {"foo" => "bar"}) }.to raise_error(Floe::PathError, "references an invalid value")
      end

      it "with a single value" do
        expect(described_class.new("$$.foo").value({"foo" => "bar"}, {})).to eq("bar")
      end

      it "with a nested hash" do
        expect(described_class.new("$$.foo.bar").value({"foo" => {"bar" => "baz"}}, {})).to eq("baz")
      end

      it "with an array" do
        expect(described_class.new("$$.foo[0].bar").value({"foo" => [{"bar" => "baz"}, {"bar" => "foo"}]})).to eq("baz")
      end

      it "returning multiple values" do
        expect(described_class.new("$$.foo[*].bar").value({"foo" => [{"bar" => "baz"}, {"bar" => "foo"}]})).to eq(["baz", "foo"])
      end
    end

    context "referencing the inputs" do
      it "with a missing value" do
        expect { described_class.new("$.foo").value({"foo" => "bar"}, {}) }.to raise_error(Floe::PathError, "references an invalid value")
      end

      it "with a single value" do
        expect(described_class.new("$.foo").value({}, {"foo" => "bar"})).to eq("bar")
      end

      it "with a nested hash" do
        expect(described_class.new("$.foo.bar").value({}, {"foo" => {"bar" => "baz"}})).to eq("baz")
      end

      it "with an array" do
        expect(described_class.new("$.foo[0].bar").value({}, {"foo" => [{"bar" => "baz"}]})).to eq("baz")
      end
    end
  end
end
