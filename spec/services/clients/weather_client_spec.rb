require "rails_helper"

RSpec.describe Clients::WeatherClient do
  subject(:client) { described_class.send(:new, http_client: http_client) }

  let(:http_client) { instance_double(Clients::HttpClient) }
  let(:latitude) { 37.422 }
  let(:longitude) { -122.084 }
  let(:temperature_unit) { "fahrenheit" }
  let(:payload) { {} }

  before do
    allow(http_client).to receive(:get).with(
      "/v1/forecast",
      params: {
        latitude: latitude,
        longitude: longitude,
        current: "temperature_2m",
        daily: "temperature_2m_max,temperature_2m_min,weather_code",
        temperature_unit: temperature_unit,
        timezone: "auto",
        forecast_days: 7
      }
    ).and_return(payload)
  end

  describe "#forecast" do
    context "when the payload includes current and daily data" do
      let(:payload) do
        {
          "current" => { "temperature_2m" => 57.5 },
          "daily" => {
            "temperature_2m_max" => [67.1, 68.0, 69.0],
            "temperature_2m_min" => [50.0, 45.9, 46.0],
            "time" => %w[2026-10-27 2026-10-28 2026-10-29],
            "weather_code" => [3, 0, 999]
          }
        }
      end
      let(:expected) do
        {
          current_temperature: 57.5,
          high: 67.1,
          low: 50.0,
          temperature_unit: "fahrenheit",
          condition: "Overcast",
          extended_forecast: [
            {
              date: "2026-10-28",
              high: 68.0,
              low: 45.9,
              weather_code: 0,
              condition: "Clear sky"
            },
            {
              date: "2026-10-29",
              high: 69.0,
              low: 46.0,
              weather_code: 999,
              condition: "Unknown"
            }
          ]
        }
      end

      it "maps the current day and extended forecast" do
        expect(
          client.forecast(
            latitude: latitude,
            longitude: longitude,
            temperature_unit: temperature_unit
          )
        ).to eq(expected)
      end
    end

    context "when temperature_unit is celsius" do
      let(:temperature_unit) { "celsius" }
      let(:payload) do
        {
          "current" => { "temperature_2m" => 14.2 },
          "daily" => {
            "temperature_2m_max" => [19.5],
            "temperature_2m_min" => [10.0],
            "time" => %w[2026-10-27],
            "weather_code" => [3]
          }
        }
      end

      it "passes the unit through and returns an empty extended forecast" do
        result = client.forecast(
          latitude: latitude,
          longitude: longitude,
          temperature_unit: temperature_unit
        )

        expect(result[:temperature_unit]).to eq("celsius")
        expect(result[:extended_forecast]).to eq([])
      end
    end

    context "when the payload is incomplete" do
      let(:payload) { { "current" => { "temperature_2m" => 57.5 } } }

      it "raises InvalidResponseError" do
        expect do
          client.forecast(latitude: latitude, longitude: longitude)
        end.to raise_error(Errors::InvalidResponseError, /incomplete weather payload/i)
      end
    end
  end

  describe ".condition_for" do
    context "when the weather code is known" do
      let(:code) { 95 }
      let(:condition) { "Thunderstorm" }

      it "returns the mapped condition" do
        expect(described_class.condition_for(code)).to eq(condition)
      end
    end

    context "when the weather code is unmapped" do
      let(:code) { 1234 }
      let(:condition) { "Unknown" }

      it "returns Unknown" do
        expect(described_class.condition_for(code)).to eq(condition)
      end
    end
  end

  describe ".forecast" do
    context "when building the default HttpClient" do
      let(:payload) do
        {
          "current" => { "temperature_2m" => 57.5 },
          "daily" => {
            "temperature_2m_max" => [67.1],
            "temperature_2m_min" => [50.0],
            "time" => %w[2026-10-27],
            "weather_code" => [3]
          }
        }
      end

      before do
        allow(Clients::HttpClient).to receive(:new).and_return(http_client)
      end

      it "uses the Open-Meteo base URL and JSON Accept header" do
        described_class.forecast(
          latitude: latitude,
          longitude: longitude,
          temperature_unit: temperature_unit
        )

        expect(Clients::HttpClient).to have_received(:new).with(
          base_url: described_class::BASE_URL,
          headers: { "Accept" => "application/json" }
        )
      end
    end
  end
end
