RSpec.describe Floe::PayloadValidator do
  # only testing 1 arg. use for_* methods to test other values
  let(:payload)     { {:a => 5} }
  let(:states)      { %w[a b c] }
  let(:state_name)  { "state name" }
  let(:rule_name)   { "rule name" }

  describe ".new" do
    it "sets the payload" do
      expect(described_class.new(payload).payload).to eq(payload)
    end
  end

  describe "#with_states" do
    let(:start)     { described_class.new(payload) }
    let(:validator) { start.with_states(states) }

    it "retains payload" do
      expect(validator.payload).to eq(payload)
    end

    it "sets state_names" do
      expect(validator.state_names).to eq(states)
    end

    it "displays proper prefix (private)" do
      expect(validator.send(:src_reference)).to eq("Workflow")
    end
  end

  describe "#for_state" do
    let(:start)       { described_class.new(payload, states) }
    let(:new_payload) { {:b => 5} }
    let(:validator)   { start.for_state(state_name, new_payload) }

    it "retains values" do
      expect(validator.state_names).to eq(states)
    end

    it "sets state_name and payload" do
      expect(validator.state_name).to eq(state_name)
      expect(validator.payload).to eq(new_payload)
    end

    it "displays proper prefix (private)" do
      expect(validator.send(:src_reference)).to eq("State [#{state_name}]")
    end
  end

  describe "#for_rule" do
    let(:start)       { described_class.new(payload, states, state_name) }
    let(:new_payload) { {:b => 5} }
    let(:validator)   { start.for_rule(rule_name, new_payload) }

    it "retains values" do
      expect(start.payload).to eq(payload)
      expect(start.state_names).to eq(states)
      expect(start.state_name).to eq(state_name)
    end

    it "sets rule name and payload" do
      expect(validator.rule).to eq(rule_name)
      expect(validator.payload).to eq(new_payload)
      expect(validator.children).to be_falsey
    end

    it "displays proper prefix (private)" do
      expect(validator.send(:src_reference)).to eq("State [#{state_name}] #{rule_name}")
    end
  end

  describe "#for_children" do
    let(:start)       { described_class.new(payload, states, state_name, :rule => rule_name) }
    let(:new_payload) { {:b => 5} }
    let(:validator)   { start.for_children(new_payload) }

    it "retains values" do
      expect(start.payload).to eq(payload)
      expect(start.state_names).to eq(states)
      expect(start.state_name).to eq(state_name)
      expect(validator.rule).to eq(rule_name)
    end

    it "sets rule name and payload" do
      expect(validator.children).to eq(true)
      expect(validator.payload).to eq(new_payload)
    end

    it "displays proper prefix (private)" do
      expect(validator.send(:src_reference)).to eq("State [#{state_name}] #{rule_name} child rule")
    end
  end

  # attribute readers

  describe "#string!" do
    it "fails missing payload without default" do
      validator = described_class.new({}, %w[A], "A")
      expect { validator.string!("missing") }.to raise_error(Floe::InvalidWorkflowError, "State [A] requires field \"missing\"")
    end

    it "fails a wrong type" do
      validator = described_class.new({"bad" => 5}, %w[A], "A")
      expect { validator.string!("bad") }.to raise_error(Floe::InvalidWorkflowError, "State [A] requires field \"bad\" to be a String but got [5]")
    end

    it "fetches missing payload when not required" do
      validator = described_class.new({}, %w[A], "A")
      expect(validator.string!("missing", :required => false)).to eq(nil)
    end

    it "fetches a string" do
      validator = described_class.new({"good" => "yay"}, %w[A], "A")
      expect(validator.string!("good")).to eq("yay")
    end
  end

  describe "#boolean!" do
    it "fails a wrong type" do
      validator = described_class.new({"bad" => 5}, %w[A], "A")
      expect { validator.boolean!("bad") }.to raise_error(Floe::InvalidWorkflowError, "State [A] requires field \"bad\" to be a Boolean but got [5]")
    end

    it "defaults missing payload to false" do
      validator = described_class.new({}, %w[A], "A")
      expect(validator.boolean!("missing")).to eq(false)
    end

    it "fetches a true" do
      validator = described_class.new({"good" => true}, %w[A], "A")
      expect(validator.boolean!("good")).to eq(true)
    end

    it "fetches a false" do
      validator = described_class.new({"good" => false}, %w[A], "A")
      expect(validator.boolean!("good")).to eq(false)
    end
  end

  describe "#number!" do
    it "fails a wrong type" do
      validator = described_class.new({"bad" => false}, %w[A], "A")
      expect { validator.number!("bad") }.to raise_error(Floe::InvalidWorkflowError, "State [A] requires field \"bad\" to be a Number but got [false]")
    end

    it "defaults to nil" do
      validator = described_class.new({}, %w[A], "A")
      expect(validator.number!("missing")).to eq(nil)
    end

    it "fetches a number" do
      validator = described_class.new({"good" => 22}, %w[A], "A")
      expect(validator.number!("good")).to eq(22)
    end

    it "fetches a float" do
      validator = described_class.new({"good" => 2.2}, %w[A], "A")
      expect(validator.number!("good")).to eq(2.2)
    end
  end

  describe "#list!" do
    it "fails missing payload without default" do
      validator = described_class.new({}, %w[A], "A")
      expect { validator.list!("missing") }.to raise_error(Floe::InvalidWorkflowError, "State [A] requires non-empty Array field \"missing\"")
    end

    it "defaults an missing payload with default" do
      validator = described_class.new({}, %w[A], "A")
      expect(validator.list!("missing", :required => false)).to eq([])
    end

    it "fails a wrong type" do
      validator = described_class.new({"bad" => 5}, %w[A], "A")
      expect { validator.list!("bad") }.to raise_error(Floe::InvalidWorkflowError, "State [A] requires non-empty Array field \"bad\"")
    end

    it "detects an empty list" do
      validator = described_class.new({"empty" => []}, %w[A], "A")
      expect { validator.list!("empty") }.to raise_error(Floe::InvalidWorkflowError, "State [A] requires non-empty Array field \"empty\"")
    end

    it "allows an empty list" do
      validator = described_class.new({"empty" => []}, %w[A], "A")
      expect(validator.list!("empty", :required => false)).to eq([])
    end

    it "fetches a list" do
      validator = described_class.new({"good" => %w[A B]}, %w[A], "A")
      expect(validator.list!("good")).to eq(%w[A B])
    end

    it "fetches a hash" do
      validator = described_class.new({"good" => {"a" => "b"}}, %w[A], "A")
      expect(validator.list!("good", :klass => Hash)).to eq({"a" => "b"})
    end
  end

  describe "#state_ref!" do
    it "fails missing payload when required" do
      validator = described_class.new({}, %w[A], "A")
      expect { validator.state_ref!("missing") }.to raise_error(Floe::InvalidWorkflowError, "State [A] requires field \"missing\"")
    end

    it "defaults missing payload when not required" do
      validator = described_class.new({}, %w[A], "A")
      expect(validator.state_ref!("missing", :required => false)).to eq(nil)
    end

    it "fails a wrong type" do
      validator = described_class.new({"bad" => 5}, %w[A], "A")
      expect { validator.state_ref!("bad") }.to raise_error(Floe::InvalidWorkflowError, "State [A] requires field \"bad\" to be in \"States\" list but got [5]")
    end

    it "fails an missing ref" do
      validator = described_class.new({"none" => "C"}, %w[A], "A")
      expect { validator.state_ref!("none") }.to raise_error(Floe::InvalidWorkflowError, "State [A] requires field \"none\" to be in \"States\" list but got [C]")
    end

    it "fetches a ref" do
      validator = described_class.new({"good" => "A"}, %w[A B], "A")
      expect(validator.state_ref!("good")).to eq("A")
    end
  end
end
