module Clients
  class GeocodingClient
    BASE_URL = "https://nominatim.openstreetmap.org".freeze

    def self.lookup(address)
      new(http_client: default_http_client).lookup(address)
    end

    def initialize(http_client:)
      @http_client = http_client
    end

    def lookup(address)
      @address = address

      {
        zip_code: zip_code,
        latitude: latitude,
        longitude: longitude
      }
    end

    private

    def self.default_http_client
      user_agent = ENV.fetch("GEOCODING_USER_AGENT", "weather-forecast-api/1.0")
      HttpClient.new(
        base_url: BASE_URL,
        headers: {
          "User-Agent" => user_agent,
          "Accept" => "application/json"
        }
      )
    end
    private_class_method :default_http_client

    def results
      @results ||= @http_client.get(
        "/search",
        params: {
          q: @address,
          format: "json",
          addressdetails: 1,
          limit: 1
        }
      )
    end

    def result
      @result ||= begin
        raise Errors::InvalidAddressError, "Address not found" if results.blank?

        first = results.first
        raise Errors::InvalidResponseError, "Unexpected geocoding payload" unless first.is_a?(Hash)

        first
      end
    end

    def zip_code
      @zip_code ||= begin
        value = result.dig("address", "postcode").to_s.strip
        raise Errors::InvalidAddressError, "Zip code not found for address" if value.blank?

        value
      end
    end

    def latitude
      @latitude ||= coordinate("lat")
    end

    def longitude
      @longitude ||= coordinate("lon")
    end

    def coordinate(key)
      value = result[key]
      raise Errors::InvalidResponseError, "Missing coordinates" if value.blank?

      value.to_f
    end

    private_class_method :new
  end
end
