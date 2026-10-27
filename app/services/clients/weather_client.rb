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
      new(http_client: default_http_client).forecast(
        latitude: latitude,
        longitude: longitude,
        temperature_unit: temperature_unit
      )
    end

    def self.condition_for(code)
      CONDITION_BY_CODE.fetch(code, "Unknown")
    end

    def initialize(http_client:)
      @http_client = http_client
    end

    def forecast(latitude:, longitude:, temperature_unit: "fahrenheit")
      payload = request_forecast(
        latitude: latitude,
        longitude: longitude,
        temperature_unit: temperature_unit
      )

      current = payload.dig("current", "temperature_2m")
      daily = payload["daily"]
      raise Errors::InvalidResponseError, "Incomplete weather payload" unless current && daily

      highs = Array(daily["temperature_2m_max"])
      lows = Array(daily["temperature_2m_min"])
      times = Array(daily["time"])
      codes = Array(daily["weather_code"])

      {
        current_temperature: current,
        high: highs.first,
        low: lows.first,
        temperature_unit: temperature_unit,
        condition: self.class.condition_for(codes.first),
        extended_forecast: extended_forecast(times, highs, lows, codes)
      }
    end

    private

    def self.default_http_client
      HttpClient.new(
        base_url: BASE_URL,
        headers: { "Accept" => "application/json" }
      )
    end
    private_class_method :default_http_client

    def request_forecast(latitude:, longitude:, temperature_unit:)
      @http_client.get(
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
      )
    end

    def extended_forecast(times, highs, lows, codes)
      times.each_with_index.drop(1).map do |date, index|
        code = codes[index]
        {
          date: date,
          high: highs[index],
          low: lows[index],
          weather_code: code,
          condition: self.class.condition_for(code)
        }
      end
    end

    private_class_method :new
  end
end
