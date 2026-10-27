require "faraday"
require "json"

module Clients
  class HttpClient
    OPEN_TIMEOUT = 5
    READ_TIMEOUT = 10

    def initialize(base_url:, headers: {})
      @connection = Faraday.new(url: base_url, headers: headers) do |faraday|
        faraday.options.open_timeout = OPEN_TIMEOUT
        faraday.options.timeout = READ_TIMEOUT
        faraday.adapter Faraday.default_adapter
      end
    end

    def get(path, params: {})
      response = @connection.get(path, params)
      handle_response(response)
    rescue Faraday::TimeoutError, Faraday::ConnectionFailed => e
      raise Errors::TimeoutError, e.message
    end

    private

    def handle_response(response)
      case response.status
      when 200..299
        parse_body(response.body)
      when 429
        raise Errors::RateLimitError, "Upstream rate limit exceeded"
      when 500..599
        raise Errors::UpstreamError, "Upstream server error: #{response.status}"
      else
        raise Errors::UpstreamError, "Unexpected upstream status: #{response.status}"
      end
    end

    def parse_body(body)
      JSON.parse(body)
    rescue JSON::ParserError
      raise Errors::InvalidResponseError, "Response body is not valid JSON"
    end
  end
end
