RSpec.describe Floe::Runner do
  let(:runner) { described_class.new }

  describe ".register_scheme", ".for_resource" do
    it "registers a scheme" do
      x = Class.new
      y = Class.new

      described_class.register_scheme("x", x)
      described_class.register_scheme("y", y)

      expect(described_class.for_resource("x://abc")).to eq(x)
      expect(described_class.for_resource("y://abc")).to eq(y)
    end

    it "overrides a scheme" do
      x = Class.new
      x2 = Class.new

      described_class.register_scheme("x", x)
      described_class.register_scheme("x", x2)

      expect(described_class.for_resource("x://abc")).to eq(x2)
    end

    it "resolves a scheme lambda" do
      x = Class.new

      described_class.register_scheme("x", -> { x })

      expect(described_class.for_resource("x://abc")).to eq(x)
    end
  end

  # interface methods (not implemented)

  describe "#run_async!" do
    it "is not implemented" do
      expect { runner.run_async!("local://resource", {}, {}, {}) }.to raise_error(NotImplementedError)
    end
  end

  describe "#status!" do
    it "is not implemented" do
      expect { runner.status!({}) }.to raise_error(NotImplementedError)
    end
  end

  describe "#running?" do
    it "is not implemented" do
      expect { runner.running?({}) }.to raise_error(NotImplementedError)
    end
  end

  describe "#success?" do
    it "is not implemented" do
      expect { runner.success?({}) }.to raise_error(NotImplementedError)
    end
  end

  describe "#output" do
    it "is not implemented" do
      expect { runner.output({}) }.to raise_error(NotImplementedError)
    end
  end

  describe "#cleanup" do
    it "is not implemented" do
      expect { runner.cleanup({}) }.to raise_error(NotImplementedError)
    end
  end

  describe "#wait" do
    it "is not implemented" do
      expect(runner.respond_to?(:wait)).to eq(false)
    end
  end
end
