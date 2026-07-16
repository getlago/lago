# frozen_string_literal: true

module Integrations
  module Aggregator
    class FetchItemsJob < ApplicationJob
      queue_as "integrations"

      retry_on LagoHttpClient::HttpError, wait: :polynomially_longer, attempts: 3
      retry_on RequestLimitError, wait: :polynomially_longer, attempts: 100

      def perform(integration:)
        result = Integrations::Aggregator::ItemsService.call(integration:)
        result.raise_if_error!
      end
    end
  end
end
