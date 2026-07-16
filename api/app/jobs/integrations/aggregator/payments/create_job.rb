# frozen_string_literal: true

module Integrations
  module Aggregator
    module Payments
      class CreateJob < ApplicationJob
        include ConcurrencyThrottlable

        queue_as "integrations"

        unique :until_executed, on_conflict: :log

        retry_on LagoHttpClient::HttpError, wait: :polynomially_longer, attempts: 5
        retry_on Integrations::Aggregator::BasePayload::Failure, wait: :polynomially_longer, attempts: 10
        retry_on RequestLimitError, wait: :polynomially_longer, attempts: 100
        retry_on BaseService::ThrottlingError, wait: :polynomially_longer, attempts: 25
        retry_on Net::ReadTimeout, wait: :polynomially_longer, attempts: 25

        def perform(payment:)
          result = Integrations::Aggregator::Payments::CreateService.call(payment:)
          result.raise_if_error!
        end
      end
    end
  end
end
