# frozen_string_literal: true

module IntegrationCustomers
  class UpdateJob < ApplicationJob
    include ConcurrencyThrottlable

    queue_as "integrations"

    retry_on LagoHttpClient::HttpError, wait: :polynomially_longer, attempts: 3
    retry_on BaseService::ThrottlingError, wait: :polynomially_longer, attempts: 25

    def perform(integration_customer_params:, integration:, integration_customer:)
      result = IntegrationCustomers::UpdateService.call(
        params: integration_customer_params,
        integration:,
        integration_customer:
      )
      result.raise_if_error!
    end
  end
end
