# frozen_string_literal: true

module IntegrationCustomers
  class CreateJob < ApplicationJob
    include ConcurrencyThrottlable

    queue_as "integrations"

    retry_on LagoHttpClient::HttpError, wait: :polynomially_longer, attempts: 3
    retry_on BaseService::ThrottlingError, wait: :polynomially_longer, attempts: 25

    # It may happen that a customer was updated in a short time after it was created. As creating integration customers is a
    # long operation, by the time we receive the update we still haven't created the integration customer. Therefore we will
    # schedule a second `IntegrationCustomers::CreateJob`. This second job should be ignored if the first one is still
    # running.
    #
    # The lock key only includes integration and customer to prevent duplicate creation in external providers (e.g. NetSuite)
    # when a create and update happen in quick succession with slightly different params.
    unique :until_executed, on_conflict: :log, lock_ttl: 12.hours

    def perform(integration_customer_params:, integration:, customer:)
      IntegrationCustomers::CreateService.call!(params: integration_customer_params, integration:, customer:)
    end

    def lock_key_arguments
      [arguments.first[:integration], arguments.first[:customer]]
    end
  end
end
