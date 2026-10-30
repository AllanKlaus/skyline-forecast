require "rails_helper"

RSpec.describe Clients::GeocodingClient do
  subject(:client) { described_class.send(:new, http_client: http_client) }

  let(:http_client) { instance_double(Clients::HttpClient) }
  let(:address) { ForecastHelpers::ADDRESS }
  let(:payload) { [] }

  before do
    allow(http_client).to receive(:get).with(
      "/search",
      params: hash_including(
        q: address,
        format: "json",
        addressdetails: 1,
        limit: 1
      )
    ).and_return(payload)
  end

  describe "#lookup" do
    context "when no results are returned" do
      it "raises InvalidAddressError" do
        expect { client.lookup(address) }.to raise_error(Errors::InvalidAddressError, /not found/i)
      end
    end

    context "when the first result is not a hash" do
      let(:payload) { ["unexpected"] }

      it "raises InvalidResponseError" do
        expect { client.lookup(address) }
          .to raise_error(Errors::InvalidResponseError, /unexpected geocoding payload/i)
      end
    end

    context "when the first result includes zip and coordinates" do
      let(:payload) do
        [
          {
            "lat" => "37.422",
            "lon" => "-122.084",
            "address" => { "postcode" => "94043" }
          }
        ]
      end
      let(:expected) do
        {
          zip_code: "94043",
          latitude: 37.422,
          longitude: -122.084
        }
      end

      it "returns zip code and coordinates" do
        expect(client.lookup(address)).to eq(expected)
      end
    end

    context "when the postcode is blank" do
      let(:payload) do
        [
          {
            "lat" => "37.422",
            "lon" => "-122.084",
            "address" => { "postcode" => "  " }
          }
        ]
      end

      it "raises InvalidAddressError" do
        expect { client.lookup(address) }.to raise_error(Errors::InvalidAddressError, /zip code not found/i)
      end
    end

    context "when coordinates are missing" do
      let(:payload) do
        [
          {
            "lat" => "",
            "lon" => "-122.084",
            "address" => { "postcode" => "94043" }
          }
        ]
      end

      it "raises InvalidResponseError" do
        expect { client.lookup(address) }.to raise_error(Errors::InvalidResponseError, /missing coordinates/i)
      end
    end
  end

  describe ".lookup" do
    context "when building the default HttpClient" do
      let(:payload) do
        [
          {
            "lat" => "37.422",
            "lon" => "-122.084",
            "address" => { "postcode" => "94043" }
          }
        ]
      end
      let(:expected_headers) do
        hash_including(
          "User-Agent" => ENV.fetch("GEOCODING_USER_AGENT", "weather-forecast-api/1.0"),
          "Accept" => "application/json"
        )
      end

      before do
        allow(Clients::HttpClient).to receive(:new).and_return(http_client)
      end

      it "uses the Nominatim base URL and configured user agent" do
        described_class.lookup(address)

        expect(Clients::HttpClient).to have_received(:new).with(
          base_url: described_class::BASE_URL,
          headers: expected_headers
        )
      end
    end
  end
end
