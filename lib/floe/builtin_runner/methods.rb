module Floe
  module BuiltinRunner
    class Methods < BasicObject
      def self.http(params, _secrets, _context)
        error = http_verify_params(params)
        return BuiltinRunner.error!({}, :cause => error) if error

        method, url, headers, query, body =
          params.values_at("Method", "Url", "Headers", "QueryParameters", "Body")

        ssl = {
          "verify"          => params.dig("Ssl", "Verify"),
          "verify_hostname" => params.dig("Ssl", "VerifyHostname"),
          "hostname"        => params.dig("Ssl", "Hostname"),
          "ca_file"         => params.dig("Ssl", "CaFile"),
          "ca_path"         => params.dig("Ssl", "CaPath"),
          "verify_mode"     => params.dig("Ssl", "VerifyMode"),
          "verify_depth"    => params.dig("Ssl", "VerifyDepth"),
          "version"         => params.dig("Ssl", "Version"),
          "min_version"     => params.dig("Ssl", "MinVersion"),
          "max_version"     => params.dig("Ssl", "MaxVersion"),
          "ciphers"         => params.dig("Ssl", "Ciphers")
        }.compact

        request = {
          "timeout"       => params.dig("Options", "Timeout"),
          "read_timeout"  => params.dig("Options", "ReadTimeout"),
          "open_timeout"  => params.dig("Options", "OpenTimeout"),
          "write_timeout" => params.dig("Options", "WriteTimeout")
        }.compact

        proxy = {
          "uri"      => params.dig("Proxy", "Uri"),
          "user"     => params.dig("Proxy", "User"),
          "password" => params.dig("Proxy", "Password")
        }.compact

        connection_options = {
          :url     => url,
          :params  => query,
          :headers => headers,
          :request => (request unless request.empty?),
          :proxy   => (proxy   unless proxy.empty?),
          :ssl     => (ssl     unless ssl.empty?)
        }

        require "faraday"
        connection = ::Faraday.new(connection_options)

        if params.dig("Options", "Encoding") == "JSON"
          connection.request(:json)
          connection.response(:json)
        end

        if params.dig("Options", "FollowRedirects") != false
          require "faraday/follow_redirects"
          connection.response(:follow_redirects)
        end

        response = connection.send(method.downcase) do |request|
          request.body = body if body
        end

        output = {"Status" => response.status, "Body" => response.body, "Headers" => response.headers}

        BuiltinRunner.success!({}, :output => output)
      end

      private_class_method def self.http_verify_params(params)
        return "Missing Parameter: Url"    if params["Url"].nil?
        return "Missing Parameter: Method" if params["Method"].nil?
        return "Invalid Parameter: Method: [#{params["Method"]}], must be GET, POST, PUT, DELETE, HEAD, PATCH, OPTIONS, or TRACE" unless %w[GET POST PUT DELETE HEAD PATCH OPTIONS TRACE].include?(params["Method"])

        nil
      end

      private_class_method def self.http_status!(runner_context)
        runner_context
      end
    end
  end
end
