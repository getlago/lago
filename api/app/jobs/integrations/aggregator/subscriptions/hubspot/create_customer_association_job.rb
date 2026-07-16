# frozen_string_literal: true

module Integrations
  module Aggregator
    module Subscriptions
      module Hubspot
        class CreateCustomerAssociationJob < ApplicationJob
          queue_as "integrations"

          retry_on LagoHttpClient::HttpError, wait: :polynomially_longer, attempts: 10
          retry_on RequestLimitError, wait: :polynomially_longer, attempts: 100
          retry_on BaseService::ThrottlingError, wait: :polynomially_longer, attempts: 25

          def perform(subscription:)
            result = Integrations::Aggregator::Subscriptions::Hubspot::CreateCustomerAssociationService.call(subscription:)
            result.raise_if_error!
          end
        end
      end
    end
  end
end
