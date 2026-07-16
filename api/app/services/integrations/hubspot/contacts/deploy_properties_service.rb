# frozen_string_literal: true

module Integrations
  module Hubspot
    module Contacts
      class DeployPropertiesService < Integrations::Aggregator::BaseService
        VERSION = 1

        def action_path
          "v1/hubspot/properties"
        end

        def call
          return result unless integration.type == "Integrations::HubspotIntegration"
          return result if integration.contacts_properties_version == VERSION

          throttle!(:hubspot)

          response = http_client.post_with_response(payload, headers)
          ActiveRecord::Base.transaction do
            integration.settings = integration.reload.settings
            integration.contacts_properties_version = VERSION
            integration.save!
          end
          result.response = response
          result
        rescue LagoHttpClient::HttpError => e
          message = message(e)
          deliver_integration_error_webhook(integration:, code: "integration_error", message:)
          result
        end

        private

        def headers
          {
            "Provider-Config-Key" => "hubspot",
            "Authorization" => "Bearer #{secret_key}",
            "Connection-Id" => integration.connection_id
          }
        end

        def payload
          {
            objectType: "contacts",
            inputs: [
              {
                groupName: "contactinformation",
                name: "lago_customer_id",
                label: "Lago Customer Id",
                type: "string",
                fieldType: "text",
                displayOrder: -1,
                hasUniqueValue: true,
                searchableInGlobalSearch: true,
                formField: true
              },
              {
                groupName: "contactinformation",
                name: "lago_customer_external_id",
                label: "Lago Customer External Id",
                type: "string",
                fieldType: "text",
                displayOrder: -1,
                hasUniqueValue: true,
                searchableInGlobalSearch: true,
                formField: true
              },
              {
                groupName: "contactinformation",
                name: "lago_billing_email",
                label: "Lago Billing Email",
                type: "string",
                fieldType: "text",
                searchableInGlobalSearch: true,
                formField: true
              },
              {
                groupName: "contactinformation",
                name: "lago_customer_link",
                label: "Lago Customer Link",
                type: "string",
                fieldType: "text",
                searchableInGlobalSearch: true,
                formField: true
              }
            ]
          }.freeze
        end
      end
    end
  end
end
