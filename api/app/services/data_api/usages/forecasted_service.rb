# frozen_string_literal: true

module DataApi
  module Usages
    class ForecastedService < DataApi::BaseService
      Result = BaseResult[:forecasted_usages]

      def call
        return result.forbidden_failure! unless License.premium?

        data_forecasted_usages = http_client.get(headers:, params:)

        result.forecasted_usages = data_forecasted_usages
        result
      end

      private

      def action_path
        "usages/#{organization.id}/forecasted/"
      end
    end
  end
end
