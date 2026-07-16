# frozen_string_literal: true

module Integrations
  module Aggregator
    class AccountInformationService < BaseService
      def action_path
        "v1/account-information"
      end

      def call
        throttle!(:hubspot)

        response = http_client.get(headers:)

        result.account_information = OpenStruct.new(response)
        result
      end

      private

      def headers
        {
          "Connection-Id" => integration.connection_id,
          "Authorization" => "Bearer #{secret_key}",
          "Provider-Config-Key" => provider_key
        }
      end
    end
  end
end
