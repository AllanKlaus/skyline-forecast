require "rails_helper"

RSpec.describe Clients::HttpClient do
  subject(:client) { described_class.new(base_url: base_url, headers: headers) }

  let(:base_url) { "https://example.test" }
  let(:headers) { { "Accept" => "application/json" } }
  let(:path) { "/resource" }

  describe "#get" do
    it "returns the parsed JSON body on success" do
      stub_request(:get, "#{base_url}#{path}")
        .with(query: { "q" => "1" }, headers: headers)
        .to_return(status: 200, body: '{"ok":true}', headers: { "Content-Type" => "application/json" })

      expect(client.get(path, params: { q: "1" })).to eq("ok" => true)
    end

    it "raises InvalidResponseError when the body is not valid JSON" do
      stub_request(:get, "#{base_url}#{path}").to_return(status: 200, body: "not-json")

      expect { client.get(path) }.to raise_error(Errors::InvalidResponseError, /not valid JSON/i)
    end

    it "raises RateLimitError on 429" do
      stub_request(:get, "#{base_url}#{path}").to_return(status: 429, body: "")

      expect { client.get(path) }.to raise_error(Errors::RateLimitError, /rate limit/i)
    end

    it "raises UpstreamError on 5xx" do
      stub_request(:get, "#{base_url}#{path}").to_return(status: 503, body: "")

      expect { client.get(path) }.to raise_error(Errors::UpstreamError, /server error: 503/i)
    end

    it "raises UpstreamError on unexpected non-success statuses" do
      stub_request(:get, "#{base_url}#{path}").to_return(status: 404, body: "")

      expect { client.get(path) }.to raise_error(Errors::UpstreamError, /unexpected upstream status: 404/i)
    end

    it "raises TimeoutError when Faraday times out" do
      stub_request(:get, "#{base_url}#{path}").to_timeout

      expect { client.get(path) }.to raise_error(Errors::TimeoutError)
    end

    it "raises TimeoutError when the connection fails" do
      stub_request(:get, "#{base_url}#{path}").to_raise(Faraday::ConnectionFailed.new("DNS failure"))

      expect { client.get(path) }.to raise_error(Errors::TimeoutError, /DNS failure/)
    end
  end

  describe ".build_connection" do
    it "applies open and read timeouts" do
      connection = described_class.build_connection(base_url, headers)

      expect(connection.options.open_timeout).to eq(described_class::OPEN_TIMEOUT)
      expect(connection.options.timeout).to eq(described_class::READ_TIMEOUT)
    end
  end
end
