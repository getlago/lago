# frozen_string_literal: true

module DataApi
  module Mrrs
    class PlansService < DataApi::BaseService
      Result = BaseResult[:data_mrrs_plans]

      def call
        return result.forbidden_failure! unless License.premium?

        data_mrrs_plans = http_client.get(headers:, params:)

        result.data_mrrs_plans = data_mrrs_plans
        result
      end

      private

      def action_path
        "mrrs/#{organization.id}/plans/"
      end
    end
  end
end
