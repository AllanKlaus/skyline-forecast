module Clients
  class WeatherClient
    BASE_URL = "https://api.open-meteo.com".freeze

    CONDITION_BY_CODE = {
      0 => "Clear sky",
      1 => "Mainly clear",
      2 => "Partly cloudy",
      3 => "Overcast",
      45 => "Fog",
      48 => "Depositing rime fog",
      51 => "Light drizzle",
      53 => "Moderate drizzle",
      55 => "Dense drizzle",
      56 => "Light freezing drizzle",
      57 => "Dense freezing drizzle",
      61 => "Slight rain",
      63 => "Moderate rain",
      65 => "Heavy rain",
      66 => "Light freezing rain",
      67 => "Heavy freezing rain",
      71 => "Slight snow fall",
      73 => "Moderate snow fall",
      75 => "Heavy snow fall",
      77 => "Snow grains",
      80 => "Slight rain showers",
      81 => "Moderate rain showers",
      82 => "Violent rain showers",
      85 => "Slight snow showers",
      86 => "Heavy snow showers",
      95 => "Thunderstorm",
      96 => "Thunderstorm with slight hail",
      99 => "Thunderstorm with heavy hail"
    }.freeze

    def self.forecast(latitude:, longitude:, temperature_unit: "fahrenheit")
      new.forecast(latitude:, longitude:, temperature_unit:)
    end

    def initialize(http_client: nil)
      @http_client = http_client || HttpClient.new(
        base_url: BASE_URL,
        headers: { "Accept" => "application/json" }
      )
    end

    def forecast(latitude:, longitude:, temperature_unit: "fahrenheit")
      @latitude = latitude
      @longitude = longitude
      @temperature_unit = temperature_unit

      validate_payload!

      {
        current_temperature: current_temperature,
        high: highs.first,
        low: lows.first,
        temperature_unit: @temperature_unit,
        condition: condition_for(codes.first),
        extended_forecast: extended_forecast
      }
    end

    private

    def response_payload
      @response_payload ||= @http_client.get(
        "/v1/forecast",
        params: {
          latitude: @latitude,
          longitude: @longitude,
          current: "temperature_2m",
          daily: "temperature_2m_max,temperature_2m_min,weather_code",
          temperature_unit: @temperature_unit,
          timezone: "auto",
          forecast_days: 7
        }
      )
    end

    def validate_payload!
      return unless current_temperature.nil? || daily.nil?

      raise Errors::InvalidResponseError, "Incomplete weather payload"
    end

    def current_temperature
      return @current_temperature if defined?(@current_temperature)

      @current_temperature = response_payload.dig("current", "temperature_2m")
    end

    def daily
      return @daily if defined?(@daily)

      @daily = response_payload["daily"]
    end

    def times
      @times ||= Array(daily["time"])
    end

    def highs
      @highs ||= Array(daily["temperature_2m_max"])
    end

    def lows
      @lows ||= Array(daily["temperature_2m_min"])
    end

    def codes
      @codes ||= Array(daily["weather_code"])
    end

    def extended_forecast
      @extended_forecast ||= times.each_with_index.drop(1).map do |date, index|
        daily_entry(date, index)
      end
    end

    def daily_entry(date, index)
      code = codes[index]
      {
        date: date,
        high: highs[index],
        low: lows[index],
        weather_code: code,
        condition: condition_for(code)
      }
    end

    def condition_for(code)
      CONDITION_BY_CODE.fetch(code, "Unknown")
    end

    private_class_method :new
  end
end
