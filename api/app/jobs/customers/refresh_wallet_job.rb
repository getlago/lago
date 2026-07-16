# frozen_string_literal: true

module Customers
  class RefreshWalletJob < ApplicationJob
    queue_as do
      customer = arguments.first
      if Utils::DedicatedWorkerConfig.enabled_for?(customer&.organization_id)
        Utils::DedicatedWorkerConfig::DEDICATED_WALLETS_QUEUE
      else
        :low_priority
      end
    end

    unique :until_executed, on_conflict: :log, lock_ttl: 12.hours

    retry_on ActiveRecord::StaleObjectError, wait: :polynomially_longer, attempts: 6
    retry_on BaseService::TooManyProviderRequestsFailure, wait: :polynomially_longer, attempts: 25
    retry_on(*Integrations::Aggregator::BaseService.retryable_errors, wait: :polynomially_longer, attempts: 6)

    def perform(customer, wallet_ids: nil)
      # When targeting specific wallets, the refresh is explicitly requested (e.g. balance increase)
      # so we don't rely on the customer-wide awaiting_wallet_refresh flag.
      return if wallet_ids.nil? && !customer.awaiting_wallet_refresh?
      return if customer.error_details.tax_error.exists?

      Customers::RefreshWalletsService.call!(customer:, target_wallet_ids: wallet_ids)
    rescue BaseService::ValidationFailure => e
      tax_error = Array(e.messages[:tax_error])

      raise unless tax_error.any? { |msg| msg.include?(Integrations::Aggregator::Taxes::BaseService::CUSTOMER_ADDRESS_INVALID) }

      ErrorDetails::CreateService.call!(
        owner: customer,
        organization: customer.organization,
        params: {
          error_code: :tax_error,
          details: {
            tax_error: e.messages[:tax_error]&.first,
            backtrace: e.backtrace,
            error: e.inspect.to_json
          }.compact
        }
      )
    end
  end
end
