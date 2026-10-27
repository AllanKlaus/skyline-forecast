module Api
  module V1
    class ForecastsController < ApplicationController
      rescue_from Errors::BadRequestError, with: :render_bad_request

      def show
        address = params[:address].to_s.strip
        raise Errors::BadRequestError, "Address is required" if address.blank?

        head :not_implemented
      end

      private

      def render_bad_request(exception)
        render json: { error: exception.message }, status: :bad_request
      end
    end
  end
end
