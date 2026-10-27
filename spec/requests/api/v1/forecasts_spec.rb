require "rails_helper"

RSpec.describe "Api::V1::Forecasts", type: :request do
  describe "GET /api/v1/forecasts" do
    it "returns 400 when address is missing" do
      get "/api/v1/forecasts"

      expect(response).to have_http_status(:bad_request)
      expect(JSON.parse(response.body)).to eq("error" => "Address is required")
    end

    it "returns 400 when address is blank" do
      get "/api/v1/forecasts", params: { address: "   " }

      expect(response).to have_http_status(:bad_request)
      expect(JSON.parse(response.body)).to eq("error" => "Address is required")
    end
  end
end
