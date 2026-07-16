# frozen_string_literal: true

module Integrations
  module Aggregator
    module Subscriptions
      module Payloads
        class BasePayload < Integrations::Aggregator::BasePayload
          def initialize(integration_customer:, subscription:)
            super(integration: integration_customer.integration, billing_entity: subscription.customer.billing_entity)

            @subscription = subscription
            @integration_customer = integration_customer
          end

          def integration_subscription
            @integration_subscription ||=
              IntegrationResource.find_by(integration:, syncable: subscription, resource_type: "subscription")
          end

          private

          attr_reader :integration_customer, :subscription

          def subscription_url
            url = ENV["LAGO_FRONT_URL"].presence || "https://app.getlago.com"

            URI.join(url, "/#{integration_customer.customer.organization.slug}/customer/#{integration_customer.customer.id}/subscription/#{subscription.id}/overview").to_s
          end
        end
      end
    end
  end
end
