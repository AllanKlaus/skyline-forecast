module Api
  module V1
    class ForecastsController < ApplicationController
      ALLOWED_TEMPERATURE_UNITS = %w[fahrenheit celsius].freeze

      rescue_from Errors::BadRequestError, with: :render_bad_request

      def show
        address = params[:address].to_s.strip
        raise Errors::BadRequestError, "Address is required" if address.blank?

        temperature_unit = params[:unit].to_s.strip.downcase.presence || "fahrenheit"
        unless ALLOWED_TEMPERATURE_UNITS.include?(temperature_unit)
          raise Errors::BadRequestError, "Unit must be fahrenheit or celsius"
        end

        result = ForecastLookup.call(address: address, temperature_unit: temperature_unit)
        render json: result, status: :ok
      end

      private

      def render_bad_request(exception)
        render json: { error: exception.message }, status: :bad_request
      end
    end
  end
end
