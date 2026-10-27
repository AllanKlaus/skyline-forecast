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

      def render_unprocessable(exception)
        render json: { error: exception.message }, status: :unprocessable_content
      end

      def render_bad_gateway(exception)
        render json: { error: exception.message }, status: :bad_gateway
      end
    end
  end
end
