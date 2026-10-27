require "faraday"
require "json"

module Clients
  class HttpClient
    OPEN_TIMEOUT = 5
    READ_TIMEOUT = 10

    def initialize(base_url:, headers: {})
      @connection = self.class.build_connection(base_url, headers)
    end

    def get(path, params: {})
      response = @connection.get(path, params)
      handle_response(response)
    rescue Faraday::TimeoutError, Faraday::ConnectionFailed => error
      raise Errors::TimeoutError, error.message
    end

    def self.build_connection(base_url, headers)
      Faraday.new(url: base_url, headers: headers) do |connection|
        options = connection.options
        options.open_timeout = OPEN_TIMEOUT
        options.timeout = READ_TIMEOUT
        connection.adapter Faraday.default_adapter
      end
    end

    private

    def handle_response(response)
      status = response.status
      case status
      when 200..299
        parse_body(response.body)
      when 429
        raise Errors::RateLimitError, "Upstream rate limit exceeded"
      when 500..599
        raise Errors::UpstreamError, "Upstream server error: #{status}"
      else
        raise Errors::UpstreamError, "Unexpected upstream status: #{status}"
      end
    end

    def parse_body(body)
      JSON.parse(body)
    rescue JSON::ParserError
      raise Errors::InvalidResponseError, "Response body is not valid JSON"
    end
  end
end
