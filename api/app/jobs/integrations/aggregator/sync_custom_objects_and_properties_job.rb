# frozen_string_literal: true

module Integrations
  module Aggregator
    class SyncCustomObjectsAndPropertiesJob < ApplicationJob
      queue_as "integrations"

      retry_on BaseService::ThrottlingError, wait: :polynomially_longer, attempts: 25

      def perform(integration:)
        Integrations::Hubspot::Invoices::DeployObjectService.call(integration:)
        Integrations::Hubspot::Subscriptions::DeployObjectService.call(integration:)
        Integrations::Hubspot::Companies::DeployPropertiesService.call(integration:)
        Integrations::Hubspot::Contacts::DeployPropertiesService.call(integration:)
      end
    end
  end
end
