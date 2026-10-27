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

    it "returns cached true on subsequent requests for the same zip code",
       vcr: { cassette_name: "forecasts/success_fahrenheit" } do
      get "/api/v1/forecasts", params: { address: ForecastHelpers::ADDRESS }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["cached"]).to eq(false)

      get "/api/v1/forecasts", params: { address: ForecastHelpers::ADDRESS }
      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body["cached"]).to eq(true)
      expect(body["zip_code"]).to eq(ForecastHelpers::ZIP_CODE)
      expect(body["current_temperature"]).to eq(57.5)
      expect(a_request(:get, %r{https://api\.open-meteo\.com/v1/forecast})).to have_been_made.once
    end

    it "expires cached forecasts after 30 minutes",
       vcr: { cassette_name: "forecasts/success_fahrenheit" } do
      get "/api/v1/forecasts", params: { address: ForecastHelpers::ADDRESS }
      expect(response.parsed_body["cached"]).to eq(false)

      travel 31.minutes do
        get "/api/v1/forecasts", params: { address: ForecastHelpers::ADDRESS }
        expect(response.parsed_body["cached"]).to eq(false)
        expect(a_request(:get, %r{https://api\.open-meteo\.com/v1/forecast})).to have_been_made.twice
      end
    end

    it "caches forecasts separately per temperature unit",
       vcr: { cassette_name: "forecasts/success_both_units" } do
      get "/api/v1/forecasts", params: { address: ForecastHelpers::ADDRESS, unit: "fahrenheit" }
      expect(response.parsed_body).to include("cached" => false, "temperature_unit" => "fahrenheit")

      get "/api/v1/forecasts", params: { address: ForecastHelpers::ADDRESS, unit: "celsius" }
      expect(response.parsed_body).to include("cached" => false, "temperature_unit" => "celsius")

      get "/api/v1/forecasts", params: { address: ForecastHelpers::ADDRESS, unit: "celsius" }
      expect(response.parsed_body).to include("cached" => true, "temperature_unit" => "celsius")

      expect(
        a_request(:get, %r{https://api\.open-meteo\.com/v1/forecast})
          .with(query: hash_including("temperature_unit" => "fahrenheit"))
      ).to have_been_made.once
      expect(
        a_request(:get, %r{https://api\.open-meteo\.com/v1/forecast})
          .with(query: hash_including("temperature_unit" => "celsius"))
      ).to have_been_made.once
    end

    it "returns 422 when the address cannot be geocoded",
       vcr: { cassette_name: "forecasts/geocode_not_found" } do
      get "/api/v1/forecasts", params: { address: "Nowhere Land" }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body).to include("error" => a_string_matching(/not found/i))
    end

    it "returns 422 when geocoding result has no zip code",
       vcr: { cassette_name: "forecasts/geocode_no_zip" } do
      get "/api/v1/forecasts", params: { address: "Some Place" }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body).to include("error" => a_string_matching(/zip/i))
    end

    it "returns 422 when an upstream payload is not parseable JSON",
       vcr: { cassette_name: "forecasts/geocode_invalid_json" } do
      get "/api/v1/forecasts", params: { address: ForecastHelpers::ADDRESS }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body).to include("error")
    end

    it "returns 502 when an upstream request times out",
       vcr: { cassette_name: "forecasts/upstream_timeout" } do
      get "/api/v1/forecasts", params: { address: ForecastHelpers::ADDRESS }

      expect(response).to have_http_status(:bad_gateway)
      expect(response.parsed_body).to include("error")
    end

    it "returns 502 when an upstream API returns 429",
       vcr: { cassette_name: "forecasts/upstream_rate_limit" } do
      get "/api/v1/forecasts", params: { address: ForecastHelpers::ADDRESS }

      expect(response).to have_http_status(:bad_gateway)
      expect(response.parsed_body).to include("error")
    end

    it "returns 502 when an upstream API returns 5xx",
       vcr: { cassette_name: "forecasts/upstream_server_error" } do
      get "/api/v1/forecasts", params: { address: ForecastHelpers::ADDRESS }

      expect(response).to have_http_status(:bad_gateway)
      expect(response.parsed_body).to include("error")
    end

    it "returns 502 when DNS resolution fails",
       vcr: { cassette_name: "forecasts/upstream_dns_failure" } do
      get "/api/v1/forecasts", params: { address: ForecastHelpers::ADDRESS }

      expect(response).to have_http_status(:bad_gateway)
      expect(response.parsed_body).to include("error")
    end
  end
end
