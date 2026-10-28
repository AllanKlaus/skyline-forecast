class HomeController < ApplicationController
  ALLOWED_TEMPERATURE_UNITS = %w[fahrenheit celsius].freeze

  def index
    return unless lookup_requested?

    @forecast = ForecastLookup.call(
      address: address,
      zip: zip,
      temperature_unit: temperature_unit
    )
  rescue Errors::BadRequestError, Errors::InvalidAddressError, Errors::InvalidResponseError,
         Errors::TimeoutError, Errors::RateLimitError, Errors::UpstreamError => error
    @error = error.message
  end

  private

  def lookup_requested?
    params.key?(:address) || params.key?(:zip)
  end

  def address
    params[:address].to_s.strip.presence
  end

  def zip
    params[:zip].to_s.strip.presence
  end

  def temperature_unit
    raise Errors::BadRequestError, "Address or zip is required" unless address || zip

    value = params[:unit].to_s.strip.downcase.presence || "fahrenheit"
    return value if ALLOWED_TEMPERATURE_UNITS.include?(value)

    raise Errors::BadRequestError, "Unit must be fahrenheit or celsius"
  end
end
