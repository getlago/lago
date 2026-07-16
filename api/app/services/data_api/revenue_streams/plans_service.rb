# frozen_string_literal: true

module DataApi
  module RevenueStreams
    class PlansService < DataApi::BaseService
      Result = BaseResult[:data_revenue_streams_plans]

      def call
        return result.forbidden_failure! unless License.premium?

        data_revenue_streams_plans = http_client.get(headers:, params:)

        result.data_revenue_streams_plans = data_revenue_streams_plans
        result
      end

      private

      def action_path
        "revenue_streams/#{organization.id}/plans/"
      end
    end
  end
end
