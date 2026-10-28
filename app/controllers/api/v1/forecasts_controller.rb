module Api
  module V1
    class ForecastsController < ApplicationController
      ALLOWED_TEMPERATURE_UNITS = %w[fahrenheit celsius].freeze

      rescue_from Errors::BadRequestError, with: :render_bad_request
      rescue_from Errors::InvalidAddressError, with: :render_unprocessable
      rescue_from Errors::InvalidResponseError, with: :render_unprocessable
      rescue_from Errors::TimeoutError, with: :render_bad_gateway
      rescue_from Errors::RateLimitError, with: :render_bad_gateway
      rescue_from Errors::UpstreamError, with: :render_bad_gateway

      def show
        render json: forecast_result, status: :ok
      end

      private

      def forecast_result
        ForecastLookup.call(
          address: address,
          zip: zip,
          temperature_unit: temperature_unit
        )
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

      def render_bad_request(exception)
        render json: { error: exception.message }, status: :bad_request
      end

      def render_unprocessable(exception)
        render json: { error: exception.message }, status: :unprocessable_content
      end

      def render_bad_gateway(exception)
        render json: { error: exception.message }, status: :bad_gateway
      end
    end
  end
end
