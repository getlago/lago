# frozen_string_literal: true

module DataApi
  module RevenueStreams
    class CustomersService < DataApi::BaseService
      Result = BaseResult[:data_revenue_streams_customers]

      def call
        return result.forbidden_failure! unless License.premium?

        data_revenue_streams_customers = http_client.get(headers:, params:)
        result.data_revenue_streams_customers = data_revenue_streams_customers
        result
      end

      private

      def action_path
        "revenue_streams/#{organization.id}/customers/"
      end
    end
  end
end
