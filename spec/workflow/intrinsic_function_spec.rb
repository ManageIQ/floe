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

      it "with an empty string" do
        result = described_class.value("States.Array('')")
        expect(result).to eq([""])
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
        expect(result).to eq([]) # This matches the stepfunctions simulator and is not [[]]
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

        expect { described_class.value("States.ArrayPartition(1, 4)") }.to raise_error(ArgumentError, "wrong type for argument 1 to States.ArrayPartition (given Integer, expected Array)")
        expect { described_class.value("States.ArrayPartition(States.Array(), 'foo')") }.to raise_error(ArgumentError, "wrong type for argument 2 to States.ArrayPartition (given String, expected Integer)")

        expect { described_class.value("States.ArrayPartition(States.Array(), -1)") }.to raise_error(ArgumentError, "invalid value for argument 2 to States.ArrayPartition (given -1, expected a positive Integer)")
        expect { described_class.value("States.ArrayPartition(States.Array(), 0)") }.to raise_error(ArgumentError, "invalid value for argument 2 to States.ArrayPartition (given 0, expected a positive Integer)")
      end
    end

    describe "States.ArrayContains" do
      # NOTE: The stepfunctions simulator fails with States.Array() passed as a parameter, but we support it

      it "with an array containing the target value" do
        result = described_class.value("States.ArrayContains(States.Array(1, 2, 3, 4, 5, 6, 7, 8, 9), 5)")
        expect(result).to eq(true)
      end

      it "with an array missing the target value" do
        result = described_class.value("States.ArrayContains(States.Array(1, 2, 3), 5)")
        expect(result).to eq(false)
      end

      it "with an empty array" do
        result = described_class.value("States.ArrayContains(States.Array(), 5)")
        expect(result).to eq(false)
      end

      it "with jsonpath for the array" do
        result = described_class.value("States.ArrayContains($.array, 5)", {}, {"array" => [1, 2, 3, 4, 5, 6, 7, 8, 9]})
        expect(result).to eq(true)
      end

      it "with jsonpath for the array and target value" do
        result = described_class.value("States.ArrayContains($.array, $.target)", {}, {"array" => [1, 2, 3, 4, 5, 6, 7, 8, 9], "target" => 5})
        expect(result).to eq(true)
      end

      it "with string values in the array" do
        result = described_class.value("States.ArrayContains($.array, '5')", {}, {"array" => %w[1 2 3 4 5 6 7 8 9]})
        expect(result).to eq(true)
      end

      it "with string values in the array but an integer target value" do
        result = described_class.value("States.ArrayContains($.array, 5)", {}, {"array" => %w[1 2 3 4 5 6 7 8 9]})
        expect(result).to eq(false)
      end

      it "fails with invalid args" do
        expect { described_class.value("States.ArrayContains()") }.to raise_error(ArgumentError, "wrong number of arguments to States.ArrayContains (given 0, expected 2)")
        expect { described_class.value("States.ArrayContains(1)") }.to raise_error(ArgumentError, "wrong number of arguments to States.ArrayContains (given 1, expected 2)")
        expect { described_class.value("States.ArrayContains(States.Array(), 1, 'foo')") }.to raise_error(ArgumentError, "wrong number of arguments to States.ArrayContains (given 3, expected 2)")

        expect { described_class.value("States.ArrayContains(1, 5)") }.to raise_error(ArgumentError, "wrong type for argument 1 to States.ArrayContains (given Integer, expected Array)")
      end
    end

    describe "States.ArrayRange" do
      it "with a positive ascending range, incrementing" do
        result = described_class.value("States.ArrayRange(1, 9, 2)")
        expect(result).to eq([1, 3, 5, 7, 9])
      end

      it "with a spanning ascending range, incrementing" do
        result = described_class.value("States.ArrayRange(-1, 9, 2)")
        expect(result).to eq([-1, 1, 3, 5, 7, 9])
      end

      it "with a negative ascending range, incrementing" do
        result = described_class.value("States.ArrayRange(-9, -1, 2)")
        expect(result).to eq([-9, -7, -5, -3, -1])
      end

      it "with a postive descending range, decrementing" do
        result = described_class.value("States.ArrayRange(9, 1, -2)")
        expect(result).to eq([9, 7, 5, 3, 1])
      end

      it "with a spanning descending range, decrementing" do
        result = described_class.value("States.ArrayRange(9, -1, -2)")
        expect(result).to eq([9, 7, 5, 3, 1, -1])
      end

      it "with a negative descending range, decrementing" do
        result = described_class.value("States.ArrayRange(-1, -9, -2)")
        expect(result).to eq([-1, -3, -5, -7, -9])
      end

      it "with a positive ascending range, decrementing" do
        result = described_class.value("States.ArrayRange(1, 9, -2)")
        expect(result).to eq([])
      end

      it "with a negative ascending range, decrementing" do
        result = described_class.value("States.ArrayRange(-9, -1, -2)")
        expect(result).to eq([])
      end

      it "with a positive descending range, incrementing" do
        result = described_class.value("States.ArrayRange(9, 1, 2)")
        expect(result).to eq([])
      end

      it "with a negative descending range, incrementing" do
        result = described_class.value("States.ArrayRange(-1, -9, 2)")
        expect(result).to eq([])
      end

      it "with jsonpath for the range start, range end, and increment" do
        result = described_class.value("States.ArrayRange($.start, $.end, $.increment)", {}, {"start" => 1, "end" => 9, "increment" => 2})
        expect(result).to eq([1, 3, 5, 7, 9])
      end

      it "with an increment that doesn't land evenly" do
        result = described_class.value("States.ArrayRange(1, 9, 3)")
        expect(result).to eq([1, 4, 7])
      end

      it "fails with invalid args" do
        expect { described_class.value("States.ArrayRange()") }.to raise_error(ArgumentError, "wrong number of arguments to States.ArrayRange (given 0, expected 3)")
        expect { described_class.value("States.ArrayRange(1)") }.to raise_error(ArgumentError, "wrong number of arguments to States.ArrayRange (given 1, expected 3)")
        expect { described_class.value("States.ArrayRange(1, 9)") }.to raise_error(ArgumentError, "wrong number of arguments to States.ArrayRange (given 2, expected 3)")
        expect { described_class.value("States.ArrayRange(1, 9, 2, 4)") }.to raise_error(ArgumentError, "wrong number of arguments to States.ArrayRange (given 4, expected 3)")

        expect { described_class.value("States.ArrayRange('1', '9', '2')") }.to raise_error(ArgumentError, "wrong type for argument 1 to States.ArrayRange (given String, expected Integer)")
        expect { described_class.value("States.ArrayRange('1', 9, 2)") }.to raise_error(ArgumentError, "wrong type for argument 1 to States.ArrayRange (given String, expected Integer)")
        expect { described_class.value("States.ArrayRange(1, '9', 2)") }.to raise_error(ArgumentError, "wrong type for argument 2 to States.ArrayRange (given String, expected Integer)")
        expect { described_class.value("States.ArrayRange(1, 9, '2')") }.to raise_error(ArgumentError, "wrong type for argument 3 to States.ArrayRange (given String, expected Integer)")

        expect { described_class.value("States.ArrayRange(1, 9, 0)") }.to raise_error(ArgumentError, "invalid value for argument 3 to States.ArrayRange (given 0, expected a non-zero Integer)")
      end
    end

    describe "States.ArrayGetItem" do
      # NOTE: The stepfunctions simulator fails with States.Array() passed as a parameter, but we support it

      it "with an index in range" do
        result = described_class.value("States.ArrayGetItem(States.Array(1, 2, 3, 4, 5, 6, 7, 8, 9), 5)")
        expect(result).to eq(6)
      end

      it "with an index out of range" do
        result = described_class.value("States.ArrayGetItem(States.Array(1, 2, 3), 5)")
        expect(result).to eq(nil)
      end

      it "with an empty array" do
        result = described_class.value("States.ArrayGetItem(States.Array(), 5)")
        expect(result).to eq(nil)
      end

      it "with jsonpath for the array" do
        result = described_class.value("States.ArrayGetItem($.array, 5)", {}, {"array" => [1, 2, 3, 4, 5, 6, 7, 8, 9]})
        expect(result).to eq(6)
      end

      it "with jsonpath for the array and index" do
        result = described_class.value("States.ArrayGetItem($.array, $.index)", {}, {"array" => [1, 2, 3, 4, 5, 6, 7, 8, 9], "index" => 5})
        expect(result).to eq(6)
      end

      it "fails with invalid args" do
        expect { described_class.value("States.ArrayGetItem()") }.to raise_error(ArgumentError, "wrong number of arguments to States.ArrayGetItem (given 0, expected 2)")
        expect { described_class.value("States.ArrayGetItem(1)") }.to raise_error(ArgumentError, "wrong number of arguments to States.ArrayGetItem (given 1, expected 2)")
        expect { described_class.value("States.ArrayGetItem(States.Array(), 1, 'foo')") }.to raise_error(ArgumentError, "wrong number of arguments to States.ArrayGetItem (given 3, expected 2)")

        expect { described_class.value("States.ArrayGetItem(States.Array(), '5')") }.to raise_error(ArgumentError, "wrong type for argument 2 to States.ArrayGetItem (given String, expected Integer)")

        expect { described_class.value("States.ArrayGetItem(States.Array(), -1)") }.to raise_error(ArgumentError, "invalid value for argument 2 to States.ArrayGetItem (given -1, expected 0 or a positive Integer)")
      end
    end

    describe "States.ArrayLength" do
      # NOTE: The stepfunctions simulator fails with States.Array() passed as a parameter, but we support it

      it "with an array" do
        result = described_class.value("States.ArrayLength(States.Array(1, 2, 3, 4, 5, 6, 7, 8, 9))")
        expect(result).to eq(9)
      end

      it "with an empty array" do
        result = described_class.value("States.ArrayLength(States.Array())")
        expect(result).to eq(0)
      end

      it "with jsonpath for the array" do
        result = described_class.value("States.ArrayLength($.array)", {}, {"array" => [1, 2, 3, 4, 5, 6, 7, 8, 9]})
        expect(result).to eq(9)
      end

      it "fails with invalid args" do
        expect { described_class.value("States.ArrayLength()") }.to raise_error(ArgumentError, "wrong number of arguments to States.ArrayLength (given 0, expected 1)")
        expect { described_class.value("States.ArrayLength(States.Array(), 1)") }.to raise_error(ArgumentError, "wrong number of arguments to States.ArrayLength (given 2, expected 1)")

        expect { described_class.value("States.ArrayLength(1)") }.to raise_error(ArgumentError, "wrong type for argument 1 to States.ArrayLength (given Integer, expected Array)")
      end
    end

    describe "States.ArrayUnique" do
      # NOTE: The stepfunctions simulator fails with States.Array() passed as a parameter, but we support it

      it "with an array" do
        result = described_class.value("States.ArrayUnique(States.Array(1, 2, 3, 3, 3, 3, 3, 3, 4))")
        expect(result).to eq([1, 2, 3, 4])
      end

      it "with an empty array" do
        result = described_class.value("States.ArrayUnique(States.Array())")
        expect(result).to eq([])
      end

      it "with jsonpath for the array" do
        result = described_class.value("States.ArrayUnique($.array)", {}, {"array" => [1, 2, 3, 3, 3, 3, 3, 3, 4]})
        expect(result).to eq([1, 2, 3, 4])
      end

      it "fails with invalid args" do
        expect { described_class.value("States.ArrayUnique()") }.to raise_error(ArgumentError, "wrong number of arguments to States.ArrayUnique (given 0, expected 1)")
        expect { described_class.value("States.ArrayUnique(States.Array(), 1)") }.to raise_error(ArgumentError, "wrong number of arguments to States.ArrayUnique (given 2, expected 1)")

        expect { described_class.value("States.ArrayUnique(1)") }.to raise_error(ArgumentError, "wrong type for argument 1 to States.ArrayUnique (given Integer, expected Array)")
      end
    end

    describe "States.Base64Encode" do
      it "with a string" do
        result = described_class.value("States.Base64Encode('Data to encode')")
        expect(result).to eq("RGF0YSB0byBlbmNvZGU=")
      end

      it "with an empty string" do
        result = described_class.value("States.Base64Encode('')")
        expect(result).to eq("")
      end

      it "with jsonpath for the string" do
        result = described_class.value("States.Base64Encode($.str)", {}, {"str" => "Data to encode"})
        expect(result).to eq("RGF0YSB0byBlbmNvZGU=")
      end

      it "fails with invalid args" do
        expect { described_class.value("States.Base64Encode()") }.to raise_error(ArgumentError, "wrong number of arguments to States.Base64Encode (given 0, expected 1)")
        expect { described_class.value("States.Base64Encode('', 1)") }.to raise_error(ArgumentError, "wrong number of arguments to States.Base64Encode (given 2, expected 1)")

        expect { described_class.value("States.Base64Encode(1)") }.to raise_error(ArgumentError, "wrong type for argument 1 to States.Base64Encode (given Integer, expected String)")
      end
    end

    describe "States.Base64Decode" do
      it "with a string" do
        result = described_class.value("States.Base64Decode('RGF0YSB0byBlbmNvZGU=')")
        expect(result).to eq("Data to encode")
      end

      it "with an empty string" do
        result = described_class.value("States.Base64Decode('')")
        expect(result).to eq("")
      end

      it "with jsonpath for the string" do
        result = described_class.value("States.Base64Decode($.str)", {}, {"str" => "RGF0YSB0byBlbmNvZGU="})
        expect(result).to eq("Data to encode")
      end

      it "fails with invalid args" do
        expect { described_class.value("States.Base64Decode()") }.to raise_error(ArgumentError, "wrong number of arguments to States.Base64Decode (given 0, expected 1)")
        expect { described_class.value("States.Base64Decode('', 1)") }.to raise_error(ArgumentError, "wrong number of arguments to States.Base64Decode (given 2, expected 1)")

        expect { described_class.value("States.Base64Decode(1)") }.to raise_error(ArgumentError, "wrong type for argument 1 to States.Base64Decode (given Integer, expected String)")

        expect { described_class.value("States.Base64Decode('garbage')") }.to raise_error(ArgumentError, "invalid value for argument 1 to States.Base64Decode (invalid base64)")
      end
    end

    describe "States.Hash" do
      it "with MD5" do
        result = described_class.value("States.Hash('input data', 'MD5')")
        expect(result).to eq("812f45842bc6d66ee14572ce20db8e86")
      end

      it "with SHA-1" do
        result = described_class.value("States.Hash('input data', 'SHA-1')")
        expect(result).to eq("aaff4a450a104cd177d28d18d74485e8cae074b7")
      end

      it "with SHA-256" do
        result = described_class.value("States.Hash('input data', 'SHA-256')")
        expect(result).to eq("b4a697a057313163aee33cd8d40c66e9f0f177e00cac2de32475ffff6169c3e3")
      end

      it "with SHA-384" do
        result = described_class.value("States.Hash('input data', 'SHA-384')")
        expect(result).to eq("d28a7d5cf25a74f11a50a18452b75e04bb3d70c9dd0510d6123aa008c756511b87525bdc835ebb27e1fb9e9374a15562")
      end

      it "with SHA-512" do
        result = described_class.value("States.Hash('input data', 'SHA-512')")
        expect(result).to eq("6ce4adb348546d4f449c4d25aad9a7c9cb711d9e91982d3f0b29ca2f3f47d4ce2deba23bf2954f0f1d593fc50283731a533d30d425402d4f91316d871303aac4")
      end

      it "with an empty string" do
        result = described_class.value("States.Hash('', 'SHA-1')")
        expect(result).to eq("da39a3ee5e6b4b0d3255bfef95601890afd80709")
      end

      it "with jsonpath for the data and algorithm" do
        result = described_class.value("States.Hash($.data, $.algorithm)", {}, {"data" => "input data", "algorithm" => "SHA-1"})
        expect(result).to eq("aaff4a450a104cd177d28d18d74485e8cae074b7")
      end

      it "with an integer" do
        result = described_class.value("States.Hash($.data, 'SHA-1')", {}, {"data" => 1})
        expect(result).to eq("356a192b7913b04c54574d18c28d46e6395428ab")
      end

      it "with a float" do
        result = described_class.value("States.Hash($.data, 'SHA-1')", {}, {"data" => 1.5})
        expect(result).to eq("aa8f289ebe6d4db1b4a1038b8931ec8c2b5399fb")
      end

      it "with an array" do
        result = described_class.value("States.Hash($.data, 'SHA-1')", {}, {"data" => [1, 2, 3]})
        expect(result).to eq("9ef50cc82ae474279fb8e82896142702bccbb33a")

        result = described_class.value("States.Hash($.data, 'SHA-1')", {}, {"data" => ["1", "2", "3"]})
        expect(result).to eq("339177d03debd051467d9f6cbcffca24d94f4ab2")
      end

      it "with a hash" do
        pending("Not implemented yet")

        result = described_class.value("States.Hash($.data, 'SHA-1')", {}, {"data" => {"foo" => "bar"}})
        expect(result).to eq("dc2935b70ad43836e2e74df2d9758b1e51397997")
      end

      it "with true" do
        result = described_class.value("States.Hash($.data, 'SHA-1')", {}, {"data" => true})
        expect(result).to eq("5ffe533b830f08a0326348a9160afafc8ada44db")
      end

      it "with false" do
        result = described_class.value("States.Hash($.data, 'SHA-1')", {}, {"data" => false})
        expect(result).to eq("7cb6efb98ba5972a9b5090dc2e517fe14d12cb04")
      end

      it "fails with invalid args" do
        expect { described_class.value("States.Hash()") }.to raise_error(ArgumentError, "wrong number of arguments to States.Hash (given 0, expected 2)")
        expect { described_class.value("States.Hash('')") }.to raise_error(ArgumentError, "wrong number of arguments to States.Hash (given 1, expected 2)")
        expect { described_class.value("States.Hash('', 'SHA-1', 1)") }.to raise_error(ArgumentError, "wrong number of arguments to States.Hash (given 3, expected 2)")

        expect { described_class.value("States.Hash('', 1)") }.to raise_error(ArgumentError, "wrong type for argument 2 to States.Hash (given Integer, expected String)")

        expect { described_class.value("States.Hash(null, 'SHA-1')") }.to raise_error(ArgumentError, "invalid value for argument 1 to States.Hash (given null, expected non-null)")
        expect { described_class.value("States.Hash('', 'FOO')") }.to raise_error(ArgumentError, 'invalid value for argument 2 to States.Hash (given "FOO", expected one of "MD5", "SHA-1", "SHA-256", "SHA-384", "SHA-512")')
      end
    end

    describe "States.MathRandom" do
      it "with a start and end" do
        result = described_class.value("States.MathRandom(1, 999)")
        expect(result).to be_between(1, 999)
      end

      it "with a start, end, and seed" do
        result = described_class.value("States.MathRandom(1, 999, 1234)")
        expect(result).to be_between(1, 999)
      end

      it "with a spanning start and end" do
        result = described_class.value("States.MathRandom(-1, 999)")
        expect(result).to be_between(-1, 999)
      end

      it "with a negative start and end" do
        result = described_class.value("States.MathRandom(-999, -1)")
        expect(result).to be_between(-999, -1)
      end

      it "with a zero seed" do
        result = described_class.value("States.MathRandom(1, 999, 0)")
        expect(result).to be_between(1, 999)
      end

      it "with a negative seed" do
        result = described_class.value("States.MathRandom(1, 999, -1234)")
        expect(result).to be_between(1, 999)
      end

      it "with jsonpath for the start and end" do
        result = described_class.value("States.MathRandom($.start, $.end)", {}, {"start" => 1, "end" => 999})
        expect(result).to be_between(1, 999)
      end

      it "with jsonpath for the start, end, and seed" do
        result = described_class.value("States.MathRandom($.start, $.end, $.seed)", {}, {"start" => 1, "end" => 999, "seed" => 1234})
        expect(result).to be_between(1, 999)
      end

      it "is within the range, inclusive" do
        counts = Hash.new(0)
        50.times do
          result = described_class.value("States.MathRandom(1, 3)")
          expect(result).to be_between(1, 3)
          counts[result] += 1
        end
        counts.each_key { |n| expect(counts[n]).to be > 0 }
      end

      it "fails with invalid args" do
        expect { described_class.value("States.MathRandom()") }.to raise_error(ArgumentError, "wrong number of arguments to States.MathRandom (given 0, expected 2..3)")
        expect { described_class.value("States.MathRandom(1)") }.to raise_error(ArgumentError, "wrong number of arguments to States.MathRandom (given 1, expected 2..3)")
        expect { described_class.value("States.MathRandom(1, 2, 1234, 4)") }.to raise_error(ArgumentError, "wrong number of arguments to States.MathRandom (given 4, expected 2..3)")

        expect { described_class.value("States.MathRandom('1', 2)") }.to raise_error(ArgumentError, "wrong type for argument 1 to States.MathRandom (given String, expected Integer)")
        expect { described_class.value("States.MathRandom(1, '2')") }.to raise_error(ArgumentError, "wrong type for argument 2 to States.MathRandom (given String, expected Integer)")
        expect { described_class.value("States.MathRandom(1, 2, '1234')") }.to raise_error(ArgumentError, "wrong type for argument 3 to States.MathRandom (given String, expected Integer)")

        expect { described_class.value("States.MathRandom(1, 1)") }.to raise_error(ArgumentError, "invalid values for arguments to States.MathRandom (start must be less than end)")
        expect { described_class.value("States.MathRandom(999, 1)") }.to raise_error(ArgumentError, "invalid values for arguments to States.MathRandom (start must be less than end)")
      end
    end

    describe "States.MathAdd" do
      it "with positive integers" do
        result = described_class.value("States.MathAdd(111, 1)")
        expect(result).to eq(112)
      end

      it "with positive and negative integers" do
        result = described_class.value("States.MathAdd(111, -1)")
        expect(result).to eq(110)
      end

      it "with negative integers" do
        result = described_class.value("States.MathAdd(-111, -1)")
        expect(result).to eq(-112)
      end

      it "with jsonpath for the values" do
        result = described_class.value("States.MathAdd($.value, $.step)", {}, {"value" => 111, "step" => -1})
        expect(result).to eq(110)
      end

      it "fails with invalid args" do
        expect { described_class.value("States.MathAdd()") }.to raise_error(ArgumentError, "wrong number of arguments to States.MathAdd (given 0, expected 2)")
        expect { described_class.value("States.MathAdd(1)") }.to raise_error(ArgumentError, "wrong number of arguments to States.MathAdd (given 1, expected 2)")
        expect { described_class.value("States.MathAdd(1, 2, 3)") }.to raise_error(ArgumentError, "wrong number of arguments to States.MathAdd (given 3, expected 2)")

        expect { described_class.value("States.MathAdd('1', 2)") }.to raise_error(ArgumentError, "wrong type for argument 1 to States.MathAdd (given String, expected Integer)")
        expect { described_class.value("States.MathAdd(1, '2')") }.to raise_error(ArgumentError, "wrong type for argument 2 to States.MathAdd (given String, expected Integer)")

        # NOTE: The stepfunctions simulator does weird stuff with floats, so they are just failures for now.
        expect { described_class.value("States.MathAdd(1.5, 1)") }.to raise_error(ArgumentError, "wrong type for argument 1 to States.MathAdd (given Float, expected Integer)")
      end
    end

    describe "States.StringSplit" do
      it "with a splittable string" do
        result = described_class.value("States.StringSplit('1,2,3,4,5', ',')")
        expect(result).to eq(%w[1 2 3 4 5])
      end

      it "with a not-splittable string" do
        result = described_class.value("States.StringSplit('foo', ',')")
        expect(result).to eq(["foo"])
      end

      it "with an empty string" do
        result = described_class.value("States.StringSplit('', ',')")
        expect(result).to eq([]) # This matches the stepfunctions simulator and is not [""]
      end

      it "with spaces around the split" do
        result = described_class.value("States.StringSplit('1, 2, 3, 4, 5', ',')")
        expect(result).to eq(["1", " 2", " 3", " 4", " 5"])
      end

      it "with consecutive delimeters" do
        result = described_class.value("States.StringSplit('1    2 3 4 5', ' ')")
        expect(result).to eq(%w[1 2 3 4 5])
      end

      it "with multiple delimeters" do
        result = described_class.value("States.StringSplit('1-2]3:4+5', '-]:+')") # Regexp characters chosen here intentionally
        expect(result).to eq(%w[1 2 3 4 5])
      end

      it "with multiple consecutive delimeters" do
        result = described_class.value("States.StringSplit('1--2]+3:4]+5', '-]:+')") # Regexp characters chosen here intentionally
        expect(result).to eq(%w[1 2 3 4 5])
      end

      it "with empty splitter" do
        result = described_class.value("States.StringSplit('1,2,3,4,5', '')")
        expect(result).to eq(["1,2,3,4,5"])
      end

      it "with empty string and splitter" do
        result = described_class.value("States.StringSplit('', '')")
        expect(result).to eq([]) # This matches the stepfunctions simulator and is not [""]
      end

      it "with jsonpath for the string and splitter" do
        result = described_class.value("States.StringSplit($.string, $.splitter)", {}, {"string" => "1,2,3,4,5", "splitter" => ","})
        expect(result).to eq(%w[1 2 3 4 5])
      end

      it "fails with invalid args" do
        expect { described_class.value("States.StringSplit()") }.to raise_error(ArgumentError, "wrong number of arguments to States.StringSplit (given 0, expected 2)")
        expect { described_class.value("States.StringSplit('')") }.to raise_error(ArgumentError, "wrong number of arguments to States.StringSplit (given 1, expected 2)")
        expect { described_class.value("States.StringSplit('', ',', '')") }.to raise_error(ArgumentError, "wrong number of arguments to States.StringSplit (given 3, expected 2)")

        expect { described_class.value("States.StringSplit(1, ',')") }.to raise_error(ArgumentError, "wrong type for argument 1 to States.StringSplit (given Integer, expected String)")
        expect { described_class.value("States.StringSplit('', 2)") }.to raise_error(ArgumentError, "wrong type for argument 2 to States.StringSplit (given Integer, expected String)")
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
        ctx = {"context" => {"baz" => "qux"}}, {"input" => {"foo" => "bar"}}
        expect { described_class.value("States.Array($.xxx)", ctx) }.to raise_error(Floe::PathError, "references an invalid value")
      end
    end

    describe "with parsing errors" do
      it "does not parse missing parens" do
        expect { described_class.value("States.Array") }.to raise_error(Floe::InvalidWorkflowError, /Expected one of \[[A-Z0-9_, ]+\] at line 1 char 1./)
      end

      it "does not parse missing closing paren" do
        expect { described_class.value("States.Array(1, ") }.to raise_error(Floe::InvalidWorkflowError, /Expected one of \[[A-Z0-9_, ]+\] at line 1 char 1./)
      end

      it "does not parse trailing commas in args" do
        expect { described_class.value("States.Array(1,)") }.to raise_error(Floe::InvalidWorkflowError, /Expected one of \[[A-Z0-9_, ]+\] at line 1 char 1./)
      end

      it "keeps the parslet error as the cause" do
        error = described_class.value("States.Array") rescue $! # rubocop:disable Style/RescueModifier, Style/SpecialGlobalVars
        expect(error.cause).to be_a(Parslet::ParseFailed)
      end
    end
  end

  describe "#initialize" do
    it "raises an InvalidWorkflowError on invalid function definition" do
      expect { described_class.new("States.Array") }.to raise_error(Floe::InvalidWorkflowError, /Expected one of \[[A-Z0-9_, ]+\] at line 1 char 1./)
    end
  end
end
