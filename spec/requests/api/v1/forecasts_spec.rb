require "rails_helper"

RSpec.describe "Api::V1::Forecasts", type: :request do
  describe "GET /api/v1/forecasts" do
    it "returns 400 when address is missing" do
      get "/api/v1/forecasts"

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body).to eq("error" => "Address is required")
    end

    it "returns 400 when address is blank" do
      get "/api/v1/forecasts", params: { address: "   " }

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body).to eq("error" => "Address is required")
    end

    it "returns the forecast for a valid address",
       vcr: { cassette_name: "forecasts/success_fahrenheit" } do
      get "/api/v1/forecasts", params: { address: ForecastHelpers::ADDRESS }

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body["address"]).to eq(ForecastHelpers::ADDRESS)
      expect(body["zip_code"]).to eq(ForecastHelpers::ZIP_CODE)
      expect(body["cached"]).to eq(false)
      expect(body["current_temperature"]).to eq(57.5)
      expect(body["high"]).to eq(67.1)
      expect(body["low"]).to eq(50.0)
      expect(body["temperature_unit"]).to eq("fahrenheit")
      expect(body["condition"]).to eq("Overcast")
      expect(body["extended_forecast"]).to include(
        a_hash_including(
          "date" => "2026-10-28",
          "high" => 68.0,
          "low" => 45.9,
          "weather_code" => 3,
          "condition" => "Overcast"
        )
      )
      expect(
        a_request(:get, %r{https://api\.open-meteo\.com/v1/forecast})
          .with(query: hash_including("temperature_unit" => "fahrenheit"))
      ).to have_been_made
    end

    it "defaults temperature unit to fahrenheit when unit is blank",
       vcr: { cassette_name: "forecasts/success_fahrenheit" } do
      get "/api/v1/forecasts", params: { address: ForecastHelpers::ADDRESS, unit: "  " }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["temperature_unit"]).to eq("fahrenheit")
    end

    it "returns the forecast in celsius when unit=celsius",
       vcr: { cassette_name: "forecasts/success_celsius" } do
      get "/api/v1/forecasts", params: { address: ForecastHelpers::ADDRESS, unit: "celsius" }

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body["temperature_unit"]).to eq("celsius")
      expect(body["condition"]).to eq("Overcast")
      expect(body["current_temperature"]).to eq(14.2)
      expect(body["high"]).to eq(19.5)
      expect(body["low"]).to eq(10.0)
      expect(body["extended_forecast"]).to include(
        a_hash_including(
          "date" => "2026-10-28",
          "high" => 20.0,
          "low" => 7.7,
          "weather_code" => 3,
          "condition" => "Overcast"
        )
      )
      expect(
        a_request(:get, %r{https://api\.open-meteo\.com/v1/forecast})
          .with(query: hash_including("temperature_unit" => "celsius"))
      ).to have_been_made
    end

    it "returns 400 when unit is invalid" do
      get "/api/v1/forecasts", params: { address: ForecastHelpers::ADDRESS, unit: "kelvin" }

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body).to eq("error" => "Unit must be fahrenheit or celsius")
    end

  end
end
