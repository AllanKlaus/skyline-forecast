require "rails_helper"

RSpec.describe "Home", type: :request do
  describe "GET /" do
    it "renders a search form for address or zip" do
      get "/"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('name="address"')
      expect(response.body).to include('name="zip"')
      expect(response.body).to include('name="unit"')
      expect(response.body).to include("Search")
    end

    it "renders forecast results in a table when address is submitted",
       vcr: { cassette_name: "forecasts/success_fahrenheit" } do
      get "/", params: { address: ForecastHelpers::ADDRESS }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("<table")
      expect(response.body).to include(ForecastHelpers::ADDRESS)
      expect(response.body).to include(ForecastHelpers::ZIP_CODE)
      expect(response.body).to include("57.5")
      expect(response.body).to include("67.1")
      expect(response.body).to include("50.0")
      expect(response.body).to include("Overcast")
      expect(response.body).to include("2026-10-28")
    end

    it "renders forecast results in a table when zip is submitted",
       vcr: { cassette_name: "forecasts/success_zip_only" } do
      get "/", params: { zip: ForecastHelpers::ZIP_CODE }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("<table")
      expect(response.body).to include(ForecastHelpers::ZIP_CODE)
      expect(response.body).to include("57.5")
      expect(response.body).to include("Overcast")
    end

    it "shows an error message when lookup params are missing" do
      get "/", params: { address: "", zip: "" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Address or zip is required")
    end
  end
end
