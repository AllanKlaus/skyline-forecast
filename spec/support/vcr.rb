require "vcr"

VCR.configure do |config|
  config.cassette_library_dir = "spec/cassettes"
  config.hook_into :webmock
  config.configure_rspec_metadata!
  config.default_cassette_options = {
    record: :once,
    match_requests_on: %i[method uri],
    allow_playback_repeats: true,
    allow_unused_http_interactions: true
  }
  config.ignore_localhost = true

  # Network errors cannot be replayed as HTTP responses; raise from the cassette name.
  config.before_http_request do
    case VCR.current_cassette&.name
    when "forecasts/upstream_timeout"
      raise Faraday::TimeoutError, "execution expired"
    when "forecasts/upstream_dns_failure"
      raise Faraday::ConnectionFailed, "getaddrinfo: Name or service not known"
    end
  end
end
