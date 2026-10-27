class ForecastLookup
  def self.call(address:, temperature_unit: "fahrenheit")
    new(address:, temperature_unit:).call
  end

  def initialize(address:, temperature_unit: "fahrenheit")
    @address = address
    @temperature_unit = temperature_unit
  end

  def call
    {
      address: @address,
      zip_code: location[:zip_code],
      cached: false,
      current_temperature: weather[:current_temperature],
      high: weather[:high],
      low: weather[:low],
      temperature_unit: weather[:temperature_unit],
      condition: weather[:condition],
      extended_forecast: weather[:extended_forecast]
    }
  end

  private

  def location
    @location ||= Clients::GeocodingClient.lookup(@address)
  end

  def weather
    @weather ||= Clients::WeatherClient.forecast(
      latitude: location[:latitude],
      longitude: location[:longitude],
      temperature_unit: @temperature_unit
    )
  end

  private_class_method :new
end
