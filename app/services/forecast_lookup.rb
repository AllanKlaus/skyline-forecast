class ForecastLookup
  CACHE_TTL = 30.minutes
  RACE_CONDITION_TTL = 10.seconds
  CACHE_KEY_PREFIX = "forecast:zip".freeze

  def self.call(address:, temperature_unit: "fahrenheit")
    new(address:, temperature_unit:).call
  end

  def initialize(address:, temperature_unit: "fahrenheit")
    @address = address
    @temperature_unit = temperature_unit
    @memo = {}
  end

  def call
    cached = true
    result = Rails.cache.fetch(cache_key, expires_in: CACHE_TTL, race_condition_ttl: RACE_CONDITION_TTL) do
      cached = false
      payload
    end
    result.merge(address: @address, cached:)
  end

  private

  def location
    @memo[:location] ||= Clients::GeocodingClient.lookup(@address)
  end

  def weather
    @memo[:weather] ||= Clients::WeatherClient.forecast(
      latitude: location[:latitude],
      longitude: location[:longitude],
      temperature_unit: @temperature_unit
    )
  end

  def cache_key
    @memo[:cache_key] ||= "#{CACHE_KEY_PREFIX}:#{location[:zip_code]}:#{@temperature_unit}"
  end

  def payload
    @memo[:payload] ||= {
      address: @address,
      zip_code: location[:zip_code],
      current_temperature: weather[:current_temperature],
      high: weather[:high],
      low: weather[:low],
      temperature_unit: weather[:temperature_unit],
      condition: weather[:condition],
      extended_forecast: weather[:extended_forecast]
    }
  end

  private_class_method :new
end
