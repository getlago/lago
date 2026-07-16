# frozen_string_literal: true

module DataApi
  module V1
    class ChargesController < DataApi::BaseController
      include PremiumFeatureOnly

      def bulk_forecasted_usage_amount
        charges_data = params[:charges] || []

        if charges_data.empty?
          render json: {error: "No charges provided"}, status: :bad_request
          return
        end

        result = Charges::BulkForecastedUsageAmountService.call(
          charges_data: charges_data
        )

        render json: {
          results: result.results,
          failed_charges: result.failed_charges,
          processed_count: result.processed_count,
          failed_count: result.failed_count
        }
      end

      def resource_name
        "analytic"
      end
    end
  end
end
