# frozen_string_literal: true

module Integrations
  module Aggregator
    class PerformSyncJob < ApplicationJob
      queue_as "integrations"

      retry_on LagoHttpClient::HttpError, wait: :polynomially_longer, attempts: 3
      retry_on RequestLimitError, wait: :polynomially_longer, attempts: 100

      def perform(integration:, sync_items: true)
        sync_result = Integrations::Aggregator::SyncService.call(integration:)
        sync_result.raise_if_error!

        if sync_items
          items_result = Integrations::Aggregator::ItemsService.call(integration:)
          items_result.raise_if_error!
        end
      end
    end
  end
end
