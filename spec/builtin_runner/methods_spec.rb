RSpec.describe Floe::BuiltinRunner::Methods do
  require "floe"

  let(:ctx) { Floe::Workflow::Context.new }
  let(:secrets) { {} }

  describe ".http" do
    let(:faraday_stub) { double("Faraday::Connection") }

    before do
      require "faraday"
      allow(Faraday).to receive(:new).and_return(faraday_stub)
      allow(faraday_stub).to receive(:response).with(:follow_redirects)
    end

    context "GET" do
      it "with a missing Url parameter" do
        runner_context = described_class.http({"Method" => "GET"}, secrets, ctx)
        expect(runner_context)
          .to include(
            "running" => false,
            "success" => false,
            "output"  => failed_task_status("Missing Parameter: Url")
          )
      end

      it "with an invalid Method parameter" do
        runner_context = described_class.http({"Method" => "Fetch", "Url" => "http://localhost"}, secrets, ctx)
        expect(runner_context)
          .to include(
            "running" => false,
            "success" => false,
            "output"  => failed_task_status("Invalid Parameter: Method: [Fetch], must be GET, POST, PUT, DELETE, HEAD, PATCH, OPTIONS, or TRACE")
          )
      end

      it "defaults to Method=GET" do
        expect(faraday_stub).to receive(:get).and_return(Faraday::Response.new(:status => 200, :body => "{}"))

        runner_context = described_class.http({"Url" => "http://localhost"}, secrets, ctx)
        expect(runner_context)
          .to include(
            "running" => false,
            "success" => true,
            "output"  => {"Body" => "{}", "Headers" => nil, "Status" => 200}
          )
      end

      it "performs the get" do
        expect(faraday_stub).to receive(:get).and_return(Faraday::Response.new(:status => 200, :body => "{}"))

        params = {"Method" => "GET", "Url" => "http://localhost"}
        runner_context = described_class.http(params, secrets, ctx)
        expect(runner_context)
          .to include(
            "running" => false,
            "success" => true,
            "output"  => {"Body" => "{}", "Headers" => nil, "Status" => 200}
          )
      end

      it "with query parameters" do
        expect(Faraday)
          .to receive(:new)
          .with(hash_including(:params => {"username" => "my-user"}))
          .and_return(faraday_stub)
        expect(faraday_stub).to receive(:get).and_return(Faraday::Response.new(:status => 200, :body => "{}"))

        params = {"Method" => "GET", "Url" => "http://localhost", "QueryParameters" => {"username" => "my-user"}}
        runner_context = described_class.http(params, secrets, ctx)
        expect(runner_context)
          .to include(
            "running" => false,
            "success" => true,
            "output"  => {"Body" => "{}", "Headers" => nil, "Status" => 200}
          )
      end

      it "with ssl parameters" do
        expect(Faraday)
          .to receive(:new)
          .with(hash_including(:ssl => {"verify" => true}))
          .and_return(faraday_stub)

        expect(faraday_stub).to receive(:get).and_return(Faraday::Response.new(:status => 200, :body => "{}"))

        params = {"Method" => "GET", "Url" => "http://localhost", "Ssl" => {"Verify" => true}}
        runner_context = described_class.http(params, secrets, ctx)
        expect(runner_context)
          .to include(
            "running" => false,
            "success" => true,
            "output"  => {"Body" => "{}", "Headers" => nil, "Status" => 200}
          )
      end

      it "with proxy options" do
        expect(Faraday)
          .to receive(:new)
          .with(hash_including(:proxy => {"uri" => "https://proxy:123", "user" => "user", "password" => "password"}))
          .and_return(faraday_stub)

        expect(faraday_stub).to receive(:get).and_return(Faraday::Response.new(:status => 200, :body => "{}"))

        params = {"Method" => "GET", "Url" => "http://localhost", "Proxy" => {"Uri" => "https://proxy:123", "User" => "user", "Password" => "password"}}
        runner_context = described_class.http(params, secrets, ctx)
        expect(runner_context)
          .to include(
            "running" => false,
            "success" => true,
            "output"  => {"Body" => "{}", "Headers" => nil, "Status" => 200}
          )
      end

      it "with request options" do
        expect(Faraday)
          .to receive(:new)
          .with(hash_including(:request => {"timeout" => 30, "read_timeout" => 10, "open_timeout" => 20, "write_timeout" => 10}))
          .and_return(faraday_stub)

        expect(faraday_stub).to receive(:get).and_return(Faraday::Response.new(:status => 200, :body => "{}"))

        params = {"Method" => "GET", "Url" => "http://localhost", "Options" => {"Timeout" => 30, "ReadTimeout" => 10, "OpenTimeout" => 20, "WriteTimeout" => 10}}
        runner_context = described_class.http(params, secrets, ctx)
        expect(runner_context)
          .to include(
            "running" => false,
            "success" => true,
            "output"  => {"Body" => "{}", "Headers" => nil, "Status" => 200}
          )
      end
    end

    context "POST" do
      it "performs the post" do
        expect(faraday_stub).to receive(:post).and_return(Faraday::Response.new(:status => 200, :body => "{}"))

        params = {"Method" => "POST", "Url" => "http://localhost", "Body" => {"foo" => "bar"}, "Headers" => {"Content-Type" => "application/json"}}
        runner_context = described_class.http(params, secrets, ctx)
        expect(runner_context)
          .to include(
            "running" => false,
            "success" => true,
            "output"  => {"Body" => "{}", "Headers" => nil, "Status" => 200}
          )
      end
    end
  end

  def failed_task_status(cause = nil, error: "States.TaskFailed")
    {"Error" => error, "Cause" => cause}.compact
  end
end
