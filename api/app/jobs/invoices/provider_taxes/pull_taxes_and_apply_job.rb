# frozen_string_literal: true

module Invoices
  module ProviderTaxes
    class PullTaxesAndApplyJob < ApplicationJob
      queue_as "providers"

      unique :until_executed, on_conflict: :log, lock_ttl: 12.hours

      retry_on BaseService::ThrottlingError, wait: :polynomially_longer, attempts: 25
      retry_on LagoHttpClient::HttpError, wait: :polynomially_longer, attempts: 6
      retry_on OpenSSL::SSL::SSLError, wait: :polynomially_longer, attempts: 6
      retry_on Net::ReadTimeout, wait: :polynomially_longer, attempts: 6
      retry_on Net::OpenTimeout, wait: :polynomially_longer, attempts: 6
      retry_on(*Integrations::Aggregator::BaseService.retryable_errors, wait: :polynomially_longer, attempts: 6)
      retry_on Customers::FailedToAcquireLock, ActiveRecord::StaleObjectError, wait: :polynomially_longer, attempts: MAX_LOCK_RETRY_ATTEMPTS
      retry_on Sequenced::SequenceError, wait: :polynomially_longer, attempts: 15, jitter: 0.75

      def perform(invoice:)
        Invoices::ProviderTaxes::PullTaxesAndApplyService.call!(invoice:)
      end
    end
  end
end
