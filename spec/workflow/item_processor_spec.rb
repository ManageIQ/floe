RSpec.describe Floe::Workflow::ItemProcessor do
  it "raises an exception for missing States field" do
    payload = {"StartAt" => "Missing"}
    expect { described_class.new(payload, "Map") }
      .to raise_error(Floe::InvalidWorkflowError, "Missing field \"States\" for state [Map]")
  end

  it "raises an exception for missing StartAt field" do
    payload = {"States" => {}}
    expect { described_class.new(payload, "Map") }
      .to raise_error(Floe::InvalidWorkflowError, "Missing field \"StartAt\" for state [Map]")
  end

  it "raises an exception if StartAt isn't in States" do
    payload = {"StartAt" => "First", "States" => {"Second" => {"Type" => "Succeed"}}}
    expect { described_class.new(payload, "Map") }
      .to raise_error(Floe::InvalidWorkflowError, "\"StartAt\" not in the \"States\" field for state [Map]")
  end

  it "raises an exception if a Next state isn't in States" do
    payload = {"StartAt" => "First", "States" => {"First" => {"Type" => "Pass", "Next" => "Last"}}}
    expect { described_class.new(payload, "Map") }
      .to raise_error(Floe::InvalidWorkflowError, "\"Next\" [Last] not in \"States\" for state [First]")
  end
end
