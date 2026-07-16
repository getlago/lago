# frozen_string_literal: true

module Integrations
  module Aggregator
    module Subscriptions
      module Hubspot
        class CreateJob < ApplicationJob
          queue_as "integrations"

          retry_on LagoHttpClient::HttpError, wait: :polynomially_longer, attempts: 10
          retry_on Integrations::Aggregator::BasePayload::Failure, wait: :polynomially_longer, attempts: 10
          retry_on RequestLimitError, wait: :polynomially_longer, attempts: 100
          retry_on BaseService::ThrottlingError, wait: :polynomially_longer, attempts: 25

          def perform(subscription:)
            result = Integrations::Aggregator::Subscriptions::Hubspot::CreateService.call(subscription:)

            if result.success?
              Integrations::Aggregator::Subscriptions::Hubspot::CreateCustomerAssociationJob.perform_later(subscription:)
            end

            result.raise_if_error!
          end
        end
      end
    end
  end
end
