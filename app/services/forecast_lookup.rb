class ForecastLookup
  CACHE_TTL = 30.minutes
  RACE_CONDITION_TTL = 10.seconds
  CACHE_KEY_PREFIX = "forecast:zip".freeze

  def self.call(address: nil, zip: nil, temperature_unit: "fahrenheit")
    new(address:, zip:, temperature_unit:).call
  end

  def initialize(address: nil, zip: nil, temperature_unit: "fahrenheit")
    @address = address.presence
    @zip = zip.presence
    @temperature_unit = temperature_unit
    @memo = {}
  end

  def call
    cached = true
    result = Rails.cache.fetch(cache_key, expires_in: CACHE_TTL, race_condition_ttl: RACE_CONDITION_TTL) do
      cached = false
      payload
    end
    result.merge(address: display_address, cached:)
  end

  private

  def display_address
    @address || @zip
  end

  def location
    @memo[:location] ||= resolve_location
  end

  def resolve_location
    if @zip
      # Prefer zip: skip address geocoding (address alone can resolve hundreds of km away).
      found = Clients::GeocodingClient.lookup(@zip)
      {
        zip_code: @zip,
        latitude: found[:latitude],
        longitude: found[:longitude]
      }
    else
      Clients::GeocodingClient.lookup(@address)
    end
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
      address: display_address,
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
