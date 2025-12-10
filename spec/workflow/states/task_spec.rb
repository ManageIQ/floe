RSpec.describe Floe::Workflow::States::Task do
  let(:input)    { {"foo" => {"bar" => "baz"}, "bar" => {"baz" => "foo"}} }
  let(:ctx)      { Floe::Workflow::Context.new(:input => input.to_json) }
  let(:resource) { "docker://hello-world:latest" }
  let(:workflow) { make_workflow(ctx, payload) }

  describe "#initialize" do
    context "with missing resource" do
      let(:payload) { {"FirstState" => {"Type" => "Task", "End" => true}} }
      it do
        expect { workflow }.to raise_error(Floe::InvalidWorkflowError, "States.FirstState does not have required field \"Resource\"")
      end
    end

    context "with invalid resource scheme" do
      let(:payload) { {"FirstState" => {"Type" => "Task", "Resource" => "invalid://foo", "End" => true}} }
      it do
        expect { workflow }.to raise_error(Floe::InvalidWorkflowError, "States.FirstState field \"Resource\" value \"invalid://foo\" Invalid resource scheme [invalid]")
      end
    end

    context "with invalid TimeoutSeconds" do
      let(:payload) { {"FirstState" => {"Type" => "Task", "Resource" => "docker://hello-world", "TimeoutSeconds" => -1, "End" => true}} }
      it do
        expect { workflow }.to raise_error(Floe::InvalidWorkflowError, "States.FirstState field \"TimeoutSeconds\" value \"-1\" must be positive, non-zero integer")
      end
    end
  end

  describe "#run_async!" do
    let(:mock_runner) { double("Floe::Runner") }
    let(:container_ref) { "container-d" }

    before do
      allow(Floe::Runner).to receive(:for_resource).and_return(mock_runner)
    end

    describe "Input" do
      context "with no InputPath" do
        let(:workflow) { make_workflow(ctx, {"State" => {"Type" => "Task", "Resource" => resource, "Next" => "SuccessState"}, "SuccessState" => {"Type" => "Succeed"}}) }

        it "passes the whole context to the resource" do
          expect_run_async({"foo" => {"bar" => "baz"}, "bar" => {"baz" => "foo"}}, :output => "hello, world!")

          workflow.run_nonblock
        end
      end

      context "with an InputPath" do
        let(:workflow) do
          make_workflow(
            ctx, {
              "State"        => {
                "Type"      => "Task",
                "Resource"  => resource,
                "InputPath" => "$.foo",
                "Next"      => "SuccessState"
              },
              "SuccessState" => {"Type" => "Succeed"}
            }
          )
        end

        it "filters the context passed to the resource" do
          expect_run_async({"bar" => "baz"}, :output => nil)

          workflow.run_nonblock
        end
      end

      context "with Parameters" do
        let(:workflow) do
          make_workflow(
            ctx, {
              "State"        => {
                "Type"       => "Task",
                "Resource"   => resource,
                "Parameters" => {"var1.$" => "$.foo.bar"},
                "Next"       => "SuccessState"
              },
              "SuccessState" => {"Type" => "Succeed"}
            }
          )
        end

        it "passes the interpolated parameters to the resource" do
          expect_run_async({"var1" => "baz"}, :output => nil)

          workflow.run_nonblock
        end
      end
    end

    describe "Output" do
      let(:workflow) { make_workflow(ctx, {"State" => {"Type" => "Task", "Resource" => resource, "Next" => "SuccessState"}, "SuccessState" => {"Type" => "Succeed"}}) }

      it "uses the last line as output if it is JSON" do
        expect_run_async({"foo" => {"bar" => "baz"}, "bar" => {"baz" => "foo"}}, :output => "ABCD\nHELLO\n{\"response\":[\"192.168.1.2\"]}")

        workflow.run_nonblock

        expect(ctx.output).to eq("response" => ["192.168.1.2"])
      end

      context "with an error" do
        it "uses the last error line as output if it is JSON" do
          expect_run_async({"foo" => {"bar" => "baz"}, "bar" => {"baz" => "foo"}}, :output => "ABCD\nHELLO\n{\"Error\":\"Custom Error\"}", :success => false)

          workflow.run_nonblock

          expect(ctx.output).to eq({"Error" => "Custom Error"})
        end
      end

      it "returns nil if the output isn't JSON" do
        expect_run_async({"foo" => {"bar" => "baz"}, "bar" => {"baz" => "foo"}}, :output => "HELLO")

        workflow.run_nonblock

        expect(ctx.output).to eq("foo" => {"bar" => "baz"}, "bar" => {"baz" => "foo"})
      end

      context "ResultSelector" do
        let(:workflow) do
          make_workflow(
            ctx, {
              "State"        => {
                "Type"           => "Task",
                "Resource"       => resource,
                "ResultSelector" => {"ip_addrs.$" => "$.response"},
                "Next"           => "SuccessState"
              },
              "SuccessState" => {"Type" => "Succeed"}
            }
          )
        end

        it "filters the results" do
          expect_run_async({"foo" => {"bar" => "baz"}, "bar" => {"baz" => "foo"}}, :output => "ABCD\nHELLO\n{\"response\":[\"192.168.1.2\"],\"exit_code\":0}")

          workflow.run_nonblock

          expect(ctx.output).to eq("ip_addrs" => ["192.168.1.2"])
        end
      end

      context "ResultPath" do
        let(:workflow) do
          make_workflow(
            ctx, {
              "State"        => {"Type" => "Task", "Resource" => resource, "ResultPath" => "$.ip_addrs", "Next" => "SuccessState"},
              "SuccessState" => {"Type" => "Succeed"}
            }
          )
        end

        it "inserts the response into the input" do
          expect_run_async(input, :output => "[\"192.168.1.2\"]")

          workflow.run_nonblock

          expect(ctx.output).to eq(
            "foo"      => {"bar" => "baz"},
            "bar"      => {"baz" => "foo"},
            "ip_addrs" => ["192.168.1.2"]
          )
        end

        context "setting a Credential" do
          let(:workflow) do
            make_workflow(
              ctx, {
                "State"        => {
                  "Type"       => "Task",
                  "Resource"   => resource,
                  "ResultPath" => "$$.Credentials",
                  "Next"       => "SuccessState"
                },
                "SuccessState" => {"Type" => "Succeed"}
              }
            )
          end

          it "inserts the response into the workflow credentials" do
            expect_run_async(input, :output => "{\"token\": \"shhh!\"}")

            workflow.run_nonblock

            expect(ctx.credentials).to include("token" => "shhh!")
            expect(ctx.output).to eq(
              "foo" => {"bar" => "baz"},
              "bar" => {"baz" => "foo"}
            )
          end
        end
      end

      context "OutputPath" do
        let(:workflow) do
          make_workflow(
            ctx, {
              "State"        => {
                "Type"       => "Task",
                "Resource"   => resource,
                "ResultPath" => "$.data.ip_addrs",
                "OutputPath" => output_path,
                "Next"       => "SuccessState"
              },
              "SuccessState" => {"Type" => "Succeed"}
            }
          )
        end

        context "with the default '$'" do
          let(:output_path) { "$" }

          it "returns the entire input as the output" do
            expect_run_async(input, :output => "[\"192.168.1.2\"]")

            workflow.run_nonblock

            expect(ctx.output).to eq(
              "foo"  => {"bar" => "baz"},
              "bar"  => {"baz" => "foo"},
              "data" => {"ip_addrs" => ["192.168.1.2"]}
            )
          end
        end

        context "with a path" do
          let(:output_path) { "$.data" }

          it "filters the output" do
            expect_run_async(input, :output => "[\"192.168.1.2\"]")

            workflow.run_nonblock

            expect(ctx.output).to eq("ip_addrs" => ["192.168.1.2"])
          end
        end
      end

      context "with Credentials" do
        let(:credentials) { {"username" => "admin", "password" => "s3cret"} }
        let(:input)       { {"foo" => {"bar" => "baz"}, "bar" => {"baz" => "foo"}, "username" => "foo"} }
        let(:ctx)         { Floe::Workflow::Context.new(:input => input.to_json, :credentials => credentials) }
        let(:workflow) do
          make_workflow(
            ctx, {
              "State"        => {
                "Type"        => "Task",
                "Resource"    => resource,
                "Parameters"  => {"var1.$" => "$.foo.bar"},
                "Credentials" => credentials_spec,
                "Next"        => "SuccessState"
              },
              "SuccessState" => {"Type" => "Succeed"}
            }
          )
        end

        context "with a value from input" do
          let(:credentials_spec) { {"username.$" => "$.username"} }

          it "passes the value from input" do
            expect_run_async({"var1" => "baz"}, {"username" => "foo"}, :output => nil)

            workflow.run_nonblock
          end
        end

        context "with a value from Global Context" do
          let(:credentials_spec) { {"username.$" => "$$.Credentials.username"} }

          it "passes the value from Context Credentials" do
            expect_run_async({"var1" => "baz"}, {"username" => "admin"}, :output => nil)

            workflow.run_nonblock
          end
        end

        context "with values from both Input and Context" do
          let(:credentials_spec) { {"username.$" => "$.username", "password.$" => "$$.Credentials.password"} }

          it "passes values from both input and Context Credentials" do
            expect_run_async({"var1" => "baz"}, {"username" => "foo", "password" => "s3cret"}, :output => nil)

            workflow.run_nonblock
          end
        end
      end
    end

    describe "Retry" do
      let(:workflow) do
        make_workflow(
          ctx, {
            "State"        => {
              "Type"     => "Task",
              "Resource" => resource,
              "Retry"    => retriers,
              "Next"     => "SuccessState"
            }.compact,
            "FirstState"   => {"Type" => "Succeed"},
            "SuccessState" => {"Type" => "Succeed"},
            "FailState"    => {"Type" => "Succeed"}
          }
        )
      end

      context "with specific errors" do
        let(:retriers) { [{"ErrorEquals" => ["States.Timeout"], "MaxAttempts" => 2}] }

        it "retries if that error is raised" do
          # 1 regular run + 2 retries = 3 times
          3.times { expect_run_async(input, :error => "States.Timeout") }
          3.times { |i| Timecop.travel(Time.now.utc + (i * 10)) { workflow.run_nonblock } }

          expect(ctx.next_state).to          be_nil
          expect(ctx.state["Retrier"]).to    eq(["States.Timeout"])
          expect(ctx.state["RetryCount"]).to eq(3)
          expect(ctx.state_history.count).to eq(3)
          expect(ctx.input).to               eq(input)
          expect(ctx.output).to              eq({"Error" => "States.Timeout"})
          expect(ctx.status).to              eq("failure")
          expect(ctx.ended?).to              eq(true)
        end

        context "with IntervalSeconds" do
          let(:retriers) { [{"ErrorEquals" => ["States.Timeout"], "MaxAttempts" => 2, "IntervalSeconds" => 30}] }

          it "doesn't execute the next state immediately" do
            expect_run_async(input, :error => "States.Timeout")

            workflow.run_nonblock

            expect(workflow.end?).to           be_falsey
            expect(ctx.state_name).to          eq("State")
            expect(ctx.state["Retrier"]).to    eq(["States.Timeout"])
            expect(ctx.state["RetryCount"]).to eq(1)
            expect(ctx.state_history.count).to eq(1)
          end
        end

        context "with multiple retriers" do
          let(:retriers) { [{"ErrorEquals" => ["States.Timeout"], "MaxAttempts" => 3}, {"ErrorEquals" => ["Exception"], "Next" => "SuccessState"}] }

          it "resets the retrier if a different exception is raised" do
            workflow.start_workflow
            expect(workflow.current_state).to receive(:wait_until!).twice.with(ctx, :seconds => 1)
            expect(workflow.current_state).to receive(:wait_until!).with(ctx, :seconds => 2.0)

            expect_run_async(input, :error => "States.Timeout")
            workflow.step_nonblock

            expect(ctx.state_name).to          eq("State")
            expect(ctx.state["Retrier"]).to    eq(["States.Timeout"])
            expect(ctx.state["RetryCount"]).to eq(1)

            expect_run_async(input, :error => "States.Timeout")
            workflow.step_nonblock

            expect(ctx.state_name).to          eq("State")
            expect(ctx.state["Retrier"]).to    eq(["States.Timeout"])
            expect(ctx.state["RetryCount"]).to eq(2)

            expect_run_async(input, :error => "Exception")
            workflow.step_nonblock

            expect(ctx.state_name).to          eq("State")
            expect(ctx.state["Retrier"]).to    eq(["Exception"])
            expect(ctx.state["RetryCount"]).to eq(1)
          end
        end

        it "fails the workflow if the number of retries is greater than MaxAttempts" do
          workflow.start_workflow
          3.times { expect_run_async(input, :error => "States.Timeout") }
          expect(workflow.current_state).to receive(:wait_until!).with(ctx, :seconds => 1)
          expect(workflow.current_state).to receive(:wait_until!).with(ctx, :seconds => 2)

          3.times { workflow.step_nonblock }

          expect(ctx.next_state).to be_nil
          expect(ctx.status).to     eq("failure")
          expect(ctx.output).to     eq("Error" => "States.Timeout")
        end

        it "fails the workflow if the exception isn't caught" do
          expect_run_async(input, :output => "Exception", :success => false)

          workflow.run_nonblock

          expect(ctx.next_state).to be_nil
          expect(ctx.status).to     eq("failure")
          expect(ctx.output).to     eq("Error" => "Exception")
        end
      end

      context "with a States.ALL retrier" do
        let(:retriers) { [{"ErrorEquals" => ["States.Timeout"]}, {"ErrorEquals" => ["States.ALL"]}] }

        it "retries if that error is raised" do
          4.times { expect_run_async(input, :error => "States.Timeout") }
          4.times { |i| Timecop.travel(Time.now.utc + (i * 10)) { workflow.run_nonblock } }

          expect(ctx.next_state).to          be_nil
          expect(ctx.state["Retrier"]).to    eq(["States.Timeout"])
          expect(ctx.state["RetryCount"]).to eq(4)
        end

        it "retries if any error is raised" do
          4.times { expect_run_async(input, :error => "ABORT!") }
          4.times { |i| Timecop.travel(Time.now.utc + (i * 10)) { workflow.run_nonblock } }

          expect(ctx.next_state).to          be_nil
          expect(ctx.state["Retrier"]).to    eq(["States.ALL"])
          expect(ctx.state["RetryCount"]).to eq(4)
          expect(ctx.output).to              eq({"Error"=>"ABORT!"})
        end
      end

      context "with a Catch" do
        let(:catchers) { [{"ErrorEquals" => ["States.ALL"], "Next" => "FailState"}] }

        let(:workflow) do
          make_workflow(
            ctx, {
              "State"        => {
                "Type"     => "Task",
                "Resource" => resource,
                "Retry"    => [{"ErrorEquals" => ["States.Timeout"]}],
                "Catch"    => catchers,
                "Next"     => "SuccessState"
              },
              "FailState"    => {"Type" => "Succeed"},
              "SuccessState" => {"Type" => "Succeed"}
            }
          )
        end

        it "retry preceeds catch" do
          expect_run_async(input, :error => "States.Timeout")

          workflow.start_workflow
          workflow.step_nonblock

          expect(ctx.state_name).to          eq("State")
          expect(ctx.state["Retrier"]).to    eq(["States.Timeout"])
          expect(ctx.state["RetryCount"]).to eq(1)
        end

        it "invokes the Catch if no retriers match" do
          expect_run_async(input, :error => "Exception")

          workflow.run_nonblock

          expect(ctx.state_name).to eq("FailState")
          expect(ctx.output).to     eq({"Error" => "Exception"})
        end
      end
    end

    describe "Catch" do
      context "with specific errors" do
        let(:catchers) { [{"ErrorEquals" => ["States.Timeout"], "Next" => "FirstState"}] }
        let(:workflow) do
          make_workflow(
            ctx, {
              "State"        => {
                "Type"     => "Task",
                "Resource" => resource,
                "Catch"    => catchers,
                "Next"     => "SuccessState"
              },
              "FirstState"   => {"Type" => "Succeed"},
              "SuccessState" => {"Type" => "Succeed"}
            }
          )
        end

        context "with invalid next" do
          let(:catchers) { [{"ErrorEquals" => ["States.Timeout"], "Next" => "MissingState"}] }

          it { expect { workflow }.to raise_error(Floe::InvalidWorkflowError, "States.State.Catch.0 field \"Next\" value \"MissingState\" is not found in \"States\"") }
        end

        context "with missing next" do
          let(:catchers) { [{"ErrorEquals" => ["States.Timeout"]}] }

          it { expect { workflow }.to raise_error(Floe::InvalidWorkflowError, "States.State.Catch.0 does not have required field \"Next\"") }
        end

        it "catches the exception" do
          expect_run_async(input, :output => "States.Timeout", :success => false)

          workflow.run_nonblock

          expect(ctx.state_name).to eq("FirstState")
        end

        it "raises if the exception isn't caught" do
          expect_run_async(input, :output => "Exception", :success => false)

          workflow.run_nonblock

          expect(ctx.next_state).to be_nil
          expect(ctx.status).to     eq("failure")
          expect(ctx.output).to     eq({"Error" => "Exception"})
        end
      end

      context "with a States.ALL catcher" do
        let(:catchers) do
          [
            {"ErrorEquals" => ["States.Timeout"], "Next" => "FirstState"},
            {"ErrorEquals" => ["States.ALL"],     "Next" => "FailState"}
          ]
        end
        let(:workflow) do
          make_workflow(
            ctx,
            {
              "State"        => {
                "Type"     => "Task",
                "Resource" => resource,
                "Catch"    => catchers,
                "Next"     => "SuccessState"
              },
              "FirstState"   => {"Type" => "Succeed"},
              "SuccessState" => {"Type" => "Succeed"},
              "FailState"    => {"Type" => "Succeed"}
            }
          )
        end

        it "catches a more specific exception" do
          expect_run_async(input, :output => "States.Timeout", :success => false)

          workflow.run_nonblock

          expect(ctx.state_name).to eq("FirstState")
        end

        it "catches the exception and transits to the next state" do
          expect_run_async(input, :output => "Exception", :success => false)

          workflow.run_nonblock

          expect(ctx.state_name).to eq("FailState")
        end
      end
    end

    describe "with TimeoutSeconds" do
      let(:timeout_seconds) { 10 }
      let(:workflow) do
        make_workflow(
          ctx, {
            "State"        => {
              "Type"           => "Task",
              "Resource"       => resource,
              "TimeoutSeconds" => timeout_seconds,
              "Next"           => "SuccessState"
            },
            "FirstState"   => {"Type" => "Succeed"},
            "SuccessState" => {"Type" => "Succeed"}
          }
        )
      end

      it "raises States.Timeout error" do
        expect_run_async(input, :running => true)
        expect(mock_runner).to receive(:output).and_return({"Error" => "States.Timeout"})

        Timecop.travel(Time.now.utc - 2 * timeout_seconds) do
          workflow.run_nonblock
        end

        workflow.run_nonblock
        expect(ctx.next_state).to be_nil
        expect(ctx.status).to     eq("failure")
        expect(ctx.output).to     eq({"Error" => "States.Timeout"})
      end

      it "state finishes before timeout" do
        expect_run_async(input, :success => true, :output => nil)
        workflow.run_nonblock

        expect(ctx.next_state).to be_nil
        expect(ctx.status).to     eq("success")
        expect(workflow.end?).to  be_truthy
      end
    end
  end

  describe "#end?" do
    it "with a normal state" do
      workflow = make_workflow(ctx, {"FirstState" => {"Type" => "Task", "Resource" => resource, "Next" => "SuccessState"}, "SuccessState" => {"Type" => "Succeed"}})
      workflow.start_workflow
      state = workflow.current_state
      expect(state.end?).to be false
    end

    it "with an end state" do
      workflow = make_workflow(ctx, {"NextState" => {"Type" => "Task", "Resource" => resource, "End" => true}})
      workflow.start_workflow
      state = workflow.current_state
      expect(state.end?).to be true
    end
  end

  def expect_run_async(parameters, secrets = nil, output: :none, error: nil, cause: nil, success: nil, running: false)
    success = error.nil? if success.nil?
    output = {"Error" => error, "Cause" => cause}.compact.to_json if error
    allow(mock_runner).to receive(:status!).and_return({})
    allow(mock_runner).to receive(:running?).and_return(running)
    allow(mock_runner).to receive(:success?).and_return(success) unless success.nil?
    allow(mock_runner).to receive(:output).and_return(output) if output != :none
    allow(mock_runner).to receive(:cleanup)

    expect(mock_runner)
      .to receive(:run_async!)
      .with(resource, parameters, secrets, ctx)
      .and_return({"container_ref" => container_ref})
  end
end
