# Ignore percent-delimeter cop because our test Strings can have all kinds of
#   characters and using `%q||` keeps the tests consistent, even if it's not
#   needed.
# rubocop:disable Style/PercentLiteralDelimiters, Style/RedundantPercentQ

require 'parslet/rig/rspec'

RSpec.describe Floe::Workflow::IntrinsicFunction::Parser do
  describe "spaces" do
    subject { described_class.new.spaces }

    it do
      expect(subject).to parse(" ")
      expect(subject).to parse("  ")
      expect(subject).to parse("   ")

      expect(subject).to_not parse("")
      expect(subject).to_not parse("\t")
      expect(subject).to_not parse("a")
    end
  end

  describe "spaces?" do
    subject { described_class.new.spaces? }

    it do
      expect(subject).to parse(" ")
      expect(subject).to parse("  ")
      expect(subject).to parse("   ")
      expect(subject).to parse("")

      expect(subject).to_not parse("\t")
      expect(subject).to_not parse("\n")
    end
  end

  describe "comma_sep" do
    subject { described_class.new.comma_sep }

    it do
      expect(subject).to parse(",")
      expect(subject).to parse(", ")
      expect(subject).to parse(",  ")
    end
  end

  describe "number" do
    subject { described_class.new.number }

    it do
      expect(subject).to parse("0")
      expect(subject).to parse("1")
      expect(subject).to parse("123")

      expect(subject).to parse("-0")
      expect(subject).to parse("-1")
      expect(subject).to parse("-123")

      expect(subject).to parse("0e1")
      expect(subject).to parse("1e1")
      expect(subject).to parse("123e1")
      expect(subject).to parse("123e123")
      expect(subject).to parse("123e-1")
      expect(subject).to parse("123e-123")

      expect(subject).to parse("-0e1")
      expect(subject).to parse("-1e1")
      expect(subject).to parse("-123e1")
      expect(subject).to parse("-123e123")
      expect(subject).to parse("-123e-1")
      expect(subject).to parse("-123e-123")

      expect(subject).to parse("0.0")
      expect(subject).to parse("0.01")
      expect(subject).to parse("1.0")
      expect(subject).to parse("1.01")
      expect(subject).to parse("123.123")

      expect(subject).to parse("-0.0")
      expect(subject).to parse("-0.01")
      expect(subject).to parse("-1.0")
      expect(subject).to parse("-1.01")
      expect(subject).to parse("-123.123")

      expect(subject).to parse("0.0e1")
      expect(subject).to parse("0.0e123")
      expect(subject).to parse("0.01e1")
      expect(subject).to parse("0.01e123")
      expect(subject).to parse("123.123e1")
      expect(subject).to parse("123.123e123")
      expect(subject).to parse("123.123e-1")
      expect(subject).to parse("123.123e-123")

      expect(subject).to parse("-0.0e1")
      expect(subject).to parse("-0.0e123")
      expect(subject).to parse("-0.01e1")
      expect(subject).to parse("-0.01e123")
      expect(subject).to parse("-123.123e1")
      expect(subject).to parse("-123.123e123")
      expect(subject).to parse("-123.123e-1")
      expect(subject).to parse("-123.123e-123")

      expect(subject).to_not parse(".")
      expect(subject).to_not parse(".1")
      expect(subject).to_not parse("1.")
      expect(subject).to_not parse("-1.")
      expect(subject).to_not parse("1..2")
      expect(subject).to_not parse("1.e1")
      expect(subject).to_not parse("-1.e1")
      expect(subject).to_not parse("01")
      expect(subject).to_not parse("1e")
      expect(subject).to_not parse("e")
      expect(subject).to_not parse("e123")
    end
  end

  describe "string" do
    subject { described_class.new.string }

    it do
      expect(subject).to parse(%q|''|)
      expect(subject).to parse(%q|'str'|)
      expect(subject).to parse(%q|'str\'str'|)
      expect(subject).to parse(%q|'str\\\\str'|)

      expect(subject).to_not parse("str")
      expect(subject).to_not parse("'str")
      expect(subject).to_not parse("str'")
      expect(subject).to_not parse("'str'str'")

      # TODO: Many more test cases
    end
  end

  describe "json_path" do
    subject { described_class.new.jsonpath }

    it do
      expect(subject).to parse("$")
      expect(subject).to parse("$$")
      expect(subject).to parse("$.input")
      expect(subject).to parse("$.input.foo")
      expect(subject).to parse("$$.input")
      expect(subject).to parse("$$.input.foo")

      expect(subject).to parse(%q|$.store.book|)
      expect(subject).to parse(%q|$.store\.book|)
      expect(subject).to parse(%q|$.\stor\e.boo\k|)
      expect(subject).to parse(%q|$.store.book.title|)
      expect(subject).to parse(%q|$.foo.\.bar|)
      expect(subject).to parse(%q|$.foo\@bar.baz\[\[.\?pretty|)
      expect(subject).to parse(%q|$.&Ж中.\uD800\uDF46|)
      expect(subject).to parse(%q|$.ledgers.branch[0].pending.count|)
      expect(subject).to parse(%q|$.ledgers.branch[0]|)
      expect(subject).to parse(%q|$.ledgers[0][22][315].foo|)
      expect(subject).to parse(%q|$['store']['book']|)
      expect(subject).to parse(%q|$['store'][0]['book']|)

      # TODO: These unlikely cases should work, but we need a more thorough parser.
      expect(subject).to_not parse(%q|$['s,tore']|)
      expect(subject).to_not parse(%q|$['s)tore']|)

      expect(subject).to_not parse(%q|['input']|)
      expect(subject).to_not parse(".input")
    end
  end

  describe "arg" do
    subject { described_class.new.arg }

    it do
      expect(subject).to parse(%q|'str'|)
      expect(subject).to parse("123")
      expect(subject).to parse("true")
      expect(subject).to parse("false")
      expect(subject).to parse("null")
      expect(subject).to parse("$.input")
      expect(subject).to parse("States.Array()")
    end
  end

  describe "args" do
    subject { described_class.new.args }

    it do
      expect(subject).to parse("")
      expect(subject).to parse(%q|'str'|)
      expect(subject).to parse(%q|'str', 123|)
      expect(subject).to parse(%q|'str', 123, true, false, null, $.input|)
      expect(subject).to parse(%q|'str', 123, true, false, null, $.input, States.Array()|)
      expect(subject).to parse(%q|'str',   123,true|)
      expect(subject).to parse("null")
      expect(subject).to parse("States.Array()")
    end
  end

  describe "states_array" do
    subject { described_class.new.states_array }

    it do
      expect(subject).to parse("States.Array()")
      expect(subject).to parse(%q|States.Array('str')|)
      expect(subject).to parse(%q|States.Array('str', 123)|)
      expect(subject).to parse(%q|States.Array('str', 123, true, false, null, $.input)|)
      expect(subject).to parse(%q|States.Array('str',   123,true)|)
      expect(subject).to parse("States.Array(null)")
      expect(subject).to parse("States.Array(States.Array())")

      expect(subject).to_not parse("States.Array")
    end
  end

  describe "states_array_partition" do
    subject { described_class.new.states_array_partition }

    it do
      expect(subject).to parse("States.ArrayPartition(States.Array(1, 2, 3, 4, 5, 6, 7, 8, 9), 4)")
      expect(subject).to parse("States.ArrayPartition(States.Array(), 4)")
      expect(subject).to parse("States.ArrayPartition(States.Array(1, 2, 3), 4)")
      expect(subject).to parse("States.ArrayPartition($.array, 4)")
      expect(subject).to parse("States.ArrayPartition($.array, $.chunk)")

      # Parser will properly parse, but will fail later at transform time due to incorrect args
      expect(subject).to parse("States.ArrayPartition()")
      expect(subject).to parse("States.ArrayPartition(1)")
      expect(subject).to parse("States.ArrayPartition(States.Array(), 'foo')")
      expect(subject).to parse("States.ArrayPartition(States.Array(), 1, 'foo')")
      expect(subject).to parse("States.ArrayPartition(States.Array(), -1)")
      expect(subject).to parse("States.ArrayPartition(States.Array(), 0)")

      expect(subject).to_not parse("States.ArrayPartition")
    end
  end

  describe "states_uuid" do
    subject { described_class.new.states_uuid }

    it do
      expect(subject).to parse("States.UUID()")

      # Parser will properly parse, but will fail later at transform time due to incorrect args
      expect(subject).to parse("States.UUID(1)")

      expect(subject).to_not parse("States.UUID")
    end
  end
end

# rubocop:enable Style/PercentLiteralDelimiters, Style/RedundantPercentQ
