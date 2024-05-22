RSpec.describe Floe::Workflow::ChoiceRule do
  let(:name)      { "FirstMatchState" }
  let(:full_name) { ["States", name, "Choice", 1] }
  let(:workflow)  { make_workflow({}, {name => {"Type" => "Choice", "Choices" => [payload], "Default" => name}}) }

  describe ".build" do
    let(:payload) { {"Variable" => "$.foo", "StringEquals" => "foo", "Next" => name} }
    let(:subject) { described_class.build(workflow, full_name, payload) }

    it "works with valid next" do
      subject
    end

    context "with Variable missing" do
      let(:payload) { {"Next" => name} }

      it { expect { subject }.to raise_exception(Floe::InvalidWorkflowError, "States.FirstMatchState.Choices.0.Data requires field \"Variable\"") }
    end

    context "with non-path Variable missing" do
      let(:payload) { {"Variable" => "wrong", "Next" => name} }
      it { expect { subject }.to raise_exception(Floe::InvalidWorkflowError, "States.FirstMatchState.Choices.0.Data requires field \"Variable\" Path [wrong] must start with \"$\"") }
    end

    context "with second level Next" do
      let(:payload) { {"Not" => {"Variable" => "$.foo", "StringEquals" => "bar", "Next" => "FirstMatchState"}, "Next" => "FirstMatchState"} }

      it { expect { subject }.to raise_exception(Floe::InvalidWorkflowError, "States.FirstMatchState.Choices.0.Not.0.Data does not recognize field \"Next\"") }
    end
  end

  describe "#true?" do
    let(:subject) { described_class.build(workflow, full_name, payload).true?(context, input) }
    let(:context) { {} }

    context "with abstract top level class" do
      let(:payload) { {"Variable" => "$.foo", "StringEquals" => "foo", "Next" => name} }
      let(:input) { {} }
      let(:subject) { described_class.new(workflow, full_name + ["Data"], payload).true?(context, input) }

      it "is not implemented" do
        expect { subject }.to raise_exception(NotImplementedError)
      end
    end

    context "Boolean Expression" do
      context "Not" do
        let(:payload) { {"Not" => {"Variable" => "$.foo", "StringEquals" => "bar"}, "Next" => "FirstMatchState"} }

        context "with a second level next" do
          let(:input) { {"foo" => "foo"} }
          let(:payload) { {"Not" => {"Variable" => "$.foo", "StringEquals" => "bar", "Next" => "FirstMatchState"}, "Next" => "FirstMatchState"} }
          it { expect { subject }.to raise_exception(Floe::InvalidWorkflowError, "States.FirstMatchState.Choices.0.Not.0.Data does not recognize field \"Next\"") }
        end

        context "that is not equal to 'bar'" do
          let(:input) { {"foo" => "foo"} }

          it "returns true" do
            expect(subject).to eq(true)
          end
        end

        context "that is equal to 'bar'" do
          let(:input) { {"foo" => "bar"} }

          it "returns false" do
            expect(subject).to eq(false)
          end
        end
      end

      context "And" do
        let(:input) { {"foo" => "foo", "bar" => "bar"} }

        context "with all sub-choices being true" do
          let(:payload) { {"And" => [{"Variable" => "$.foo", "StringEquals" => "foo"}, {"Variable" => "$.bar", "StringEquals" => "bar"}], "Next" => "FirstMatchState"} }

          it "returns true" do
            expect(subject).to eq(true)
          end
        end

        context "with one sub-choice false" do
          let(:payload) { {"And" => [{"Variable" => "$.foo", "StringEquals" => "foo"}, {"Variable" => "$.bar", "StringEquals" => "foo"}], "Next" => "FirstMatchState"} }

          it "returns false" do
            expect(subject).to eq(false)
          end
        end
      end

      context "Or" do
        let(:input) { {"foo" => "foo", "bar" => "bar"} }

        context "with one sub-choice being true" do
          let(:payload) { {"Or" => [{"Variable" => "$.foo", "StringEquals" => "foo"}, {"Variable" => "$.bar", "StringEquals" => "foo"}], "Next" => "FirstMatchState"} }

          it "returns true" do
            expect(subject).to eq(true)
          end
        end

        context "with no sub-choices being true" do
          let(:payload) { {"Or" => [{"Variable" => "$.foo", "StringEquals" => "bar"}, {"Variable" => "$.bar", "StringEquals" => "foo"}], "Next" => "FirstMatchState"} }

          it "returns false" do
            expect(subject).to eq(false)
          end
        end
      end
    end

    context "Data-Test Expression" do
      context "with a missing variable" do
        let(:payload) { {"Variable" => "$.foo", "NumericEquals" => 1, "Next" => "FirstMatchState"} }
        let(:input) { {} }

        it "raises an exception" do
          expect { subject }.to raise_exception(RuntimeError, "No such variable [$.foo]")
        end
      end

      context "with a missing compare key" do
        let(:payload) { {"Variable" => "$.foo", "Next" => "FirstMatchState"} }
        let(:input) { {"foo" => "bar"} }

        it "raises an exception" do
          expect { subject }.to raise_exception(Floe::InvalidWorkflowError, "Data-test Expression Choice Rule must have a compare key")
        end
      end

      context "with an invalid compare key" do
        let(:payload) { {"Variable" => "$.foo", "InvalidCompare" => "$.bar", "Next" => "FirstMatchState"} }
        let(:input)   { {"foo" => 0, "bar" => 1} }

        it "fails" do
          expect { subject }.to raise_exception(Floe::InvalidWorkflowError)
        end
      end

      context "with IsNull" do
        let(:payload) { {"Variable" => "$.foo", "IsNull" => true, "Next" => "FirstMatchState"} }

        context "with null" do
          let(:input) { {"foo" => nil} }

          it "returns true" do
            expect(subject).to eq(true)
          end
        end

        context "with non-null" do
          let(:input) { {"foo" => "bar"} }

          it "returns false" do
            expect(subject).to eq(false)
          end
        end
      end

      context "with IsPresent" do
        let(:payload) { {"Variable" => "$.foo", "IsPresent" => true, "Next" => "FirstMatchState"} }

        context "with null" do
          let(:input) { {"foo" => nil} }

          it "returns false" do
            expect(subject).to eq(false)
          end
        end

        context "with non-null" do
          let(:input) { {"foo" => "bar"} }

          it "returns true" do
            expect(subject).to eq(true)
          end
        end
      end

      context "with IsNumeric" do
        let(:payload) { {"Variable" => "$.foo", "IsNumeric" => true, "Next" => "FirstMatchState"} }

        context "with an integer" do
          let(:input) { {"foo" => 1} }

          it "returns true" do
            expect(subject).to eq(true)
          end
        end

        context "with a float" do
          let(:input) { {"foo" => 1.5} }

          it "returns true" do
            expect(subject).to eq(true)
          end
        end

        context "with a string" do
          let(:input) { {"foo" => "bar"} }

          it "returns false" do
            expect(subject).to eq(false)
          end
        end
      end

      context "with IsString" do
        let(:payload) { {"Variable" => "$.foo", "IsString" => true, "Next" => "FirstMatchState"} }

        context "with a string" do
          let(:input) { {"foo" => "bar"} }

          it "returns true" do
            expect(subject).to eq(true)
          end
        end

        context "with a number" do
          let(:input) { {"foo" => 1} }

          it "returns false" do
            expect(subject).to eq(false)
          end
        end
      end

      context "with IsBoolean" do
        let(:payload) { {"Variable" => "$.foo", "IsBoolean" => true, "Next" => "FirstMatchState"} }

        context "with a boolean" do
          let(:input) { {"foo" => true} }

          it "returns true" do
            expect(subject).to eq(true)
          end
        end

        context "with a number" do
          let(:input) { {"foo" => 1} }

          it "returns false" do
            expect(subject).to eq(false)
          end
        end
      end

      context "with IsTimestamp" do
        let(:payload) { {"Variable" => "$.foo", "IsTimestamp" => true, "Next" => "FirstMatchState"} }

        context "with a timestamp" do
          let(:input) { {"foo" => "2016-03-14T01:59:00Z"} }

          it "returns true" do
            expect(subject).to eq(true)
          end
        end

        context "with a number" do
          let(:input) { {"foo" => 1} }

          it "returns false" do
            expect(subject).to eq(false)
          end
        end

        context "with a string that isn't a date" do
          let(:input) { {"foo" => "bar"} }

          it "returns false" do
            expect(subject).to eq(false)
          end
        end

        context "with a date that isn't in rfc3339 format" do
          let(:input) { {"foo" => "2023-01-21 16:30:32 UTC"} }

          it "returns false" do
            expect(subject).to eq(false)
          end
        end
      end

      context "with a NumericEquals" do
        let(:payload) { {"Variable" => "$.foo", "NumericEquals" => 1, "Next" => "FirstMatchState"} }

        context "that equals the variable" do
          let(:input) { {"foo" => 1} }

          it "returns true" do
            expect(subject).to eq(true)
          end
        end

        context "that does not equal the variable" do
          let(:input) { {"foo" => 2} }

          it "returns false" do
            expect(subject).to eq(false)
          end
        end
      end

      context "with a NumericEqualsPath" do
        let(:payload) { {"Variable" => "$.foo", "NumericEqualsPath" => "$.bar", "Next" => "FirstMatchState"} }

        context "that equals the variable" do
          let(:input) { {"foo" => 1, "bar" => 1} }

          it "returns true" do
            expect(subject).to eq(true)
          end
        end

        context "that does not equal the variable" do
          let(:input) { {"foo" => 2, "bar" => 1} }

          it "returns false" do
            expect(subject).to eq(false)
          end
        end
      end

      context "with a NumericLessThan" do
        let(:payload) { {"Variable" => "$.foo", "NumericLessThan" => 1, "Next" => "FirstMatchState"} }

        context "that is true" do
          let(:input) { {"foo" => 0} }

          it "returns true" do
            expect(subject).to eq(true)
          end
        end

        context "that is false" do
          let(:input) { {"foo" => 1} }

          it "returns false" do
            expect(subject).to eq(false)
          end
        end
      end

      context "with a NumericLessThanPath" do
        let(:payload) { {"Variable" => "$.foo", "NumericLessThanPath" => "$.bar", "Next" => "FirstMatchState"} }

        context "that is true" do
          let(:input) { {"foo" => 0, "bar" => 1} }

          it "returns true" do
            expect(subject).to eq(true)
          end
        end

        context "that is false" do
          let(:input) { {"foo" => 1, "bar" => 1} }

          it "returns false" do
            expect(subject).to eq(false)
          end
        end
      end

      context "with a NumericGreaterThan" do
        let(:payload) { {"Variable" => "$.foo", "NumericGreaterThan" => 1, "Next" => "FirstMatchState"} }

        context "that is true" do
          let(:input) { {"foo" => 2} }

          it "returns true" do
            expect(subject).to eq(true)
          end
        end

        context "that is false" do
          let(:input) { {"foo" => 1} }

          it "returns false" do
            expect(subject).to eq(false)
          end
        end
      end

      context "with a NumericGreaterThanPath" do
        let(:payload) { {"Variable" => "$.foo", "NumericGreaterThanPath" => "$.bar", "Next" => "FirstMatchState"} }

        context "that is true" do
          let(:input) { {"foo" => 2, "bar" => 1} }

          it "returns true" do
            expect(subject).to eq(true)
          end
        end

        context "that is false" do
          let(:input) { {"foo" => 1, "bar" => 1} }

          it "returns false" do
            expect(subject).to eq(false)
          end
        end
      end

      context "with a NumericLessThanEquals" do
        let(:payload) { {"Variable" => "$.foo", "NumericLessThanEquals" => 1, "Next" => "FirstMatchState"} }

        context "that is true" do
          let(:input) { {"foo" => 1} }

          it "returns true" do
            expect(subject).to eq(true)
          end
        end

        context "that is false" do
          let(:input) { {"foo" => 2} }

          it "returns false" do
            expect(subject).to eq(false)
          end
        end
      end

      context "with a NumericLessThanEqualsPath" do
        let(:payload) { {"Variable" => "$.foo", "NumericLessThanEqualsPath" => "$.bar", "Next" => "FirstMatchState"} }

        context "that is true" do
          let(:input) { {"foo" => 1, "bar" => 1} }

          it "returns true" do
            expect(subject).to eq(true)
          end
        end

        context "that is false" do
          let(:input) { {"foo" => 2, "bar" => 1} }

          it "returns false" do
            expect(subject).to eq(false)
          end
        end
      end

      context "with a NumericGreaterThanEquals" do
        let(:payload) { {"Variable" => "$.foo", "NumericGreaterThanEquals" => 1, "Next" => "FirstMatchState"} }

        context "that is true" do
          let(:input) { {"foo" => 1} }

          it "returns true" do
            expect(subject).to eq(true)
          end
        end

        context "that is false" do
          let(:input) { {"foo" => 0} }

          it "returns false" do
            expect(subject).to eq(false)
          end
        end
      end

      context "with a NumericGreaterThanEqualsPath" do
        let(:payload) { {"Variable" => "$.foo", "NumericGreaterThanEqualsPath" => "$.bar", "Next" => "FirstMatchState"} }

        context "that is true" do
          let(:input) { {"foo" => 1, "bar" => 1} }

          it "returns true" do
            expect(subject).to eq(true)
          end
        end

        context "that is false" do
          let(:input) { {"foo" => 0, "bar" => 1} }

          it "returns false" do
            expect(subject).to eq(false)
          end
        end
      end

      context "with a StringMatches" do
        let(:payload) { {"Variable" => "$.foo", "StringMatches" => "*.log", "Next" => "FirstMatchState"} }

        context "that is true" do
          let(:input) { {"foo" => "audit.log"} }

          it "returns true" do
            expect(subject).to eq(true)
          end
        end

        context "that is false" do
          let(:input) { {"foo" => "audit"} }

          it "returns false" do
            expect(subject).to eq(false)
          end
        end
      end
    end
  end
end
