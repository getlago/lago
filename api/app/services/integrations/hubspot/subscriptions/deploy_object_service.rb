# frozen_string_literal: true

module Integrations
  module Hubspot
    module Subscriptions
      class DeployObjectService < Integrations::Aggregator::BaseService
        VERSION = 1

        def action_path
          "v1/hubspot/object"
        end

        def call
          return result unless integration.type == "Integrations::HubspotIntegration"
          if integration.subscriptions_properties_version == VERSION &&
              integration.subscriptions_object_type_id.present?
            return result
          end

          custom_object_result = Integrations::Aggregator::CustomObjectService.call(integration:, name: "LagoSubscriptions")
          if custom_object_result.success?
            save_object_type_id(custom_object_result.custom_object&.objectTypeId)
            return result
          end

          throttle!(:hubspot)

          response = http_client.post_with_response(payload, headers)
          ActiveRecord::Base.transaction do
            save_object_type_id(JSON.parse(response.body)["objectTypeId"])
          end
          result.response = response
          result
        rescue LagoHttpClient::HttpError => e
          message = message(e)
          deliver_integration_error_webhook(integration:, code: "integration_error", message:)
          result
        end

        private

        def save_object_type_id(object_type_id)
          integration.settings = integration.reload.settings
          integration.subscriptions_object_type_id = object_type_id
          integration.subscriptions_properties_version = VERSION
          integration.save!
        end

        def headers
          {
            "Provider-Config-Key" => "hubspot",
            "Authorization" => "Bearer #{secret_key}",
            "Connection-Id" => integration.connection_id
          }
        end

        def payload
          {
            secondaryDisplayProperties: [
              "lago_external_subscription_id"
            ],
            requiredProperties: [
              "lago_subscription_id"
            ],
            searchableProperties: %w[lago_subscription_id lago_external_subscription_id],
            name: "LagoSubscriptions",
            associatedObjects: %w[COMPANY CONTACT],
            properties: [
              {
                name: "lago_subscription_id",
                label: "Lago Subscription Id",
                type: "string",
                fieldType: "text",
                hasUniqueValue: true,
                searchableInGlobalSearch: true
              },
              {
                name: "lago_external_subscription_id",
                label: "Lago External Subscription Id",
                type: "string",
                fieldType: "text",
                searchableInGlobalSearch: true
              },
              {
                name: "lago_subscription_name",
                label: "Lago Subscription Name",
                type: "string",
                fieldType: "text"
              },
              {
                name: "lago_subscription_plan_code",
                label: "Lago Subscription Plan Code",
                type: "string",
                fieldType: "text"
              },
              {
                name: "lago_subscription_status",
                label: "Lago Subscription Status",
                type: "string",
                fieldType: "text"
              },
              {
                name: "lago_subscription_created_at",
                label: "Lago Subscription Created At",
                type: "date",
                fieldType: "date"
              },
              {
                name: "lago_subscription_started_at",
                label: "Lago Subscription Started At",
                type: "date",
                fieldType: "date"
              },
              {
                name: "lago_subscription_ending_at",
                label: "Lago Subscription Ending At",
                type: "date",
                fieldType: "date"
              },
              {
                name: "lago_subscription_at",
                label: "Lago Subscription At",
                type: "date",
                fieldType: "date"
              },
              {
                name: "lago_subscription_terminated_at",
                label: "Lago Subscription Terminated At",
                type: "date",
                fieldType: "date"
              },
              {
                name: "lago_subscription_trial_ended_at",
                label: "Lago Subscription Trial Ended At",
                type: "date",
                fieldType: "date"
              },
              {
                name: "lago_billing_time",
                label: "Lago Billing Time",
                type: "enumeration",
                fieldType: "radio",
                displayOrder: -1,
                hasUniqueValue: false,
                searchableInGlobalSearch: true,
                formField: true,
                options: [
                  {
                    label: "Calendar",
                    value: "calendar",
                    displayOrder: 1
                  },
                  {
                    label: "Anniversary",
                    value: "anniversary",
                    displayOrder: 2
                  }
                ]
              }
            ],
            labels: {
              singular: "LagoSubscription",
              plural: "LagoSubscriptions"
            },
            primaryDisplayProperty: "lago_subscription_id",
            description: "string"
          }
        end
      end
    end
  end
end
