RSpec.describe Floe::Workflow::IntrinsicFunction do
  describe ".intrinsic_function?" do
    context "with an intrinsic function" do
      it "returns true" do
        expect(described_class.intrinsic_function?("States.Array(1)")).to be_truthy
      end
    end

    context "with a Path" do
      it "returns false" do
        expect(described_class.intrinsic_function?("$.foo")).to be_falsey
      end
    end

    context "with a string" do
      it "returns false" do
        expect(described_class.intrinsic_function?("foo")).to be_falsey
      end
    end
  end

  describe ".value" do
    describe "States.Array" do
      it "with no values" do
        result = described_class.value("States.Array()")
        expect(result).to eq([])
      end

      it "with a single value" do
        result = described_class.value("States.Array(1)")
        expect(result).to eq([1])
      end

      it "with a single null value" do
        result = described_class.value("States.Array(null)")
        expect(result).to eq([nil])
      end

      it "with a single array value" do
        result = described_class.value("States.Array(States.Array())")
        expect(result).to eq([[]])
      end

      it "with multiple values" do
        result = described_class.value("States.Array(1, 2, 3)")
        expect(result).to eq([1, 2, 3])
      end

      it "with different types of args" do
        result = described_class.value("States.Array('string', 1, 1.5, true, false, null, $.input)", {}, {"input" => {"foo" => "bar"}})
        expect(result).to eq(["string", 1, 1.5, true, false, nil, {"foo" => "bar"}])
      end

      it "with nested States functions" do
        result = described_class.value("States.Array(States.UUID(), States.UUID())")

        uuid_regex = /^\h{8}-\h{4}-\h{4}-\h{4}-\h{12}$/
        expect(result).to match_array([a_string_matching(uuid_regex), a_string_matching(uuid_regex)])
      end
    end

    describe "States.ArrayPartition" do
      it "with expected args" do
        result = described_class.value("States.ArrayPartition(States.Array(1, 2, 3, 4, 5, 6, 7, 8, 9), 4)")
        expect(result).to eq([[1, 2, 3, 4], [5, 6, 7, 8], [9]])
      end

      it "with an empty array" do
        result = described_class.value("States.ArrayPartition(States.Array(), 4)")
        expect(result).to eq([[]])
      end

      it "with chunk size larger than the array size" do
        result = described_class.value("States.ArrayPartition(States.Array(1, 2, 3), 4)")
        expect(result).to eq([[1, 2, 3]])
      end

      it "with jsonpath for the array" do
        result = described_class.value("States.ArrayPartition($.array, 4)", {}, {"array" => [1, 2, 3, 4, 5, 6, 7, 8, 9]})
        expect(result).to eq([[1, 2, 3, 4], [5, 6, 7, 8], [9]])
      end

      it "with jsonpath for the array and chunk size" do
        result = described_class.value("States.ArrayPartition($.array, $.chunk)", {}, {"array" => [1, 2, 3, 4, 5, 6, 7, 8, 9], "chunk" => 4})
        expect(result).to eq([[1, 2, 3, 4], [5, 6, 7, 8], [9]])
      end

      it "fails with invalid args" do
        expect { described_class.value("States.ArrayPartition()") }.to raise_error(ArgumentError, "wrong number of arguments to States.ArrayPartition (given 0, expected 2)")
        expect { described_class.value("States.ArrayPartition(1)") }.to raise_error(ArgumentError, "wrong number of arguments to States.ArrayPartition (given 1, expected 2)")
        expect { described_class.value("States.ArrayPartition(States.Array(), 1, 'foo')") }.to raise_error(ArgumentError, "wrong number of arguments to States.ArrayPartition (given 3, expected 2)")

        expect { described_class.value("States.ArrayPartition(1, 4)") }.to raise_error(ArgumentError, "wrong type for first argument to States.ArrayPartition (given Integer, expected Array)")
        expect { described_class.value("States.ArrayPartition(States.Array(), 'foo')") }.to raise_error(ArgumentError, "wrong type for second argument to States.ArrayPartition (given String, expected Integer)")

        expect { described_class.value("States.ArrayPartition(States.Array(), -1)") }.to raise_error(ArgumentError, "invalid value for second argument to States.ArrayPartition (given -1, expected a positive Integer)")
        expect { described_class.value("States.ArrayPartition(States.Array(), 0)") }.to raise_error(ArgumentError, "invalid value for second argument to States.ArrayPartition (given 0, expected a positive Integer)")
      end
    end

    describe "States.UUID" do
      it "returns a v4 UUID" do
        result = described_class.value("States.UUID()")

        match = result.match(/^\h{8}-\h{4}-(\h{4})-\h{4}-\h{12}$/)
        expect(match).to be

        uuid_version = match[1].to_i(16) >> 12
        expect(uuid_version).to eq(4)
      end

      it "fails with invalid args" do
        expect { described_class.value("States.UUID(1)") }.to raise_error(ArgumentError, "wrong number of arguments to States.UUID (given 1, expected 0)")
        expect { described_class.value("States.UUID(null)") }.to raise_error(ArgumentError, "wrong number of arguments to States.UUID (given 1, expected 0)")
        expect { described_class.value("States.UUID(1, 2)") }.to raise_error(ArgumentError, "wrong number of arguments to States.UUID (given 2, expected 0)")
      end
    end

    describe "with jsonpath args" do
      it "fetches values from the input" do
        result = described_class.value("States.Array($.input)", {"context" => {"baz" => "qux"}}, {"input" => {"foo" => "bar"}})
        expect(result).to eq([{"foo" => "bar"}])
      end

      it "fetches values from the context" do
        result = described_class.value("States.Array($$.context)", {"context" => {"baz" => "qux"}}, {"input" => {"foo" => "bar"}})
        expect(result).to eq([{"baz" => "qux"}])
      end

      it "can return the entire input" do
        result = described_class.value("States.Array($)", {"context" => {"baz" => "qux"}}, {"input" => {"foo" => "bar"}})
        expect(result).to eq([{"input" => {"foo" => "bar"}}])
      end

      it "can return the entire context" do
        result = described_class.value("States.Array($$)", {"context" => {"baz" => "qux"}}, {"input" => {"foo" => "bar"}})
        expect(result).to eq([{"context" => {"baz" => "qux"}}])
      end

      it "fetches deep values" do
        result = described_class.value("States.Array($.input.foo)", {"context" => {"baz" => "qux"}}, {"input" => {"foo" => "bar"}})
        expect(result).to eq(["bar"])
      end

      it "handles invalid path references" do
        result = described_class.value("States.Array($.xxx)", {"context" => {"baz" => "qux"}}, {"input" => {"foo" => "bar"}})
        expect(result).to eq([nil])
      end
    end

    describe "with parsing errors" do
      it "does not parse missing parens" do
        expect { described_class.value("States.Array") }.to raise_error(Floe::InvalidWorkflowError, /Expected one of \[[A-Z_, ]+\] at line 1 char 1./)
      end

      it "does not parse missing closing paren" do
        expect { described_class.value("States.Array(1, ") }.to raise_error(Floe::InvalidWorkflowError, /Expected one of \[[A-Z_, ]+\] at line 1 char 1./)
      end

      it "does not parse trailing commas in args" do
        expect { described_class.value("States.Array(1,)") }.to raise_error(Floe::InvalidWorkflowError, /Expected one of \[[A-Z_, ]+\] at line 1 char 1./)
      end

      it "keeps the parslet error as the cause" do
        error = described_class.value("States.Array") rescue $! # rubocop:disable Style/RescueModifier, Style/SpecialGlobalVars
        expect(error.cause).to be_a(Parslet::ParseFailed)
      end
    end
  end
end
