# frozen_string_literal: true

module Integrations
  module Aggregator
    class CustomObjectService < BaseService
      def initialize(integration:, name:)
        @name = name
        super(integration:)
      end

      def action_path
        "v1/#{provider}/custom-object"
      end

      def call
        throttle!(:hubspot)

        response = http_client.get(headers:, body:)

        result.custom_object = OpenStruct.new(response)
        result
      rescue LagoHttpClient::HttpError => e
        result.service_failure!(code: e.error_code, message: e.message)
      end

      private

      attr_reader :name

      def headers
        {
          "Connection-Id" => integration.connection_id,
          "Authorization" => "Bearer #{secret_key}",
          "Provider-Config-Key" => provider_key
        }
      end

      def body
        {
          "name" => name
        }
      end
    end
  end
end
