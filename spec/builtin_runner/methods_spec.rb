RSpec.describe Floe::BuiltinRunner::Methods do
  require "floe"

  let(:input)    { {"foo" => "bar"} }
  let(:start_at) { "Start" }
  let(:secrets)  { {} }
  let(:ctx) do
    Floe::Workflow::Context.new(:input => input.to_json).tap { |c| c.prepare_start(start_at) }
  end

  describe ".log" do
    let(:logdev) { StringIO.new }
    let(:logger) { Logger.new(logdev) }

    around do |example|
      orig_logger, Floe.logger = Floe.logger, logger
      example.run
    ensure
      Floe.logger = orig_logger
    end

    def expect_log_message(level, message)
      log = logdev.tap(&:rewind).read.chomp
      level_label = Logger::SEV_LABEL[Logger::Severity.const_get(level)]
      expect(log).to end_with(" #{level_label.rjust(5, " ")} -- : #{message}")
    end

    def expect_no_log_message
      log = logdev.tap(&:rewind).read.chomp
      expect(log).to be_empty
    end

    described_class::LOG_SEVERITIES.each do |level|
      it level do
        runner_context = described_class.log({"Level" => level, "Message" => "Hello, Floe!"}, secrets, ctx)

        expect_log_message(level, "Hello, Floe!")
        expect(runner_context)
          .to include(
            "running" => false,
            "success" => true,
            "output"  => input
          )
      end
    end

    it "with a missing Message parameter" do
      runner_context = described_class.log({"Level" => "INFO"}, secrets, ctx)

      expect_no_log_message
      expect(runner_context)
        .to include(
          "running" => false,
          "success" => false,
          "output"  => failed_task_status("Missing Parameter: Message")
        )
    end

    it "with a missing Level parameter, defaults to INFO" do
      runner_context = described_class.log({"Message" => "Hello, Floe!"}, secrets, ctx)

      expect_log_message("INFO", "Hello, Floe!")
      expect(runner_context)
        .to include(
          "running" => false,
          "success" => true,
          "output"  => input
        )
    end

    it "with an invalid Level parameter" do
      runner_context = described_class.log({"Level" => "XXX", "Message" => "Hello, Floe!"}, secrets, ctx)

      expect_no_log_message
      expect(runner_context)
        .to include(
          "running" => false,
          "success" => false,
          "output"  => failed_task_status("Invalid Parameter: Level: [XXX], must be one of DEBUG, INFO, WARN, ERROR, FATAL, or UNKNOWN")
        )
    end

    it "accepts lowercase Level parameter" do
      runner_context = described_class.log({"Level" => "info", "Message" => "Hello, Floe!"}, secrets, ctx)

      expect_log_message("INFO", "Hello, Floe!")
      expect(runner_context)
        .to include(
          "running" => false,
          "success" => true,
          "output"  => input
        )
    end
  end

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
