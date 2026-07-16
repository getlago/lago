# frozen_string_literal: true

module LifetimeUsages
  class CheckThresholdsService < BaseService
    Result = BaseResult[:invoice]

    def initialize(lifetime_usage:)
      @lifetime_usage = lifetime_usage

      super
    end

    def call
      return result unless subscription.active?

      passed_thresholds = LifetimeUsages::UsageThresholds::CheckService.call!(lifetime_usage:, progressive_billed_amount:).passed_thresholds

      if passed_thresholds.any?
        invoice_result = Invoices::ProgressiveBillingService.call(sorted_usage_thresholds: passed_thresholds, lifetime_usage:)
        # If there is tax error, invoice is marked as failed and it can be retried manually
        invoice_result.raise_if_error! unless tax_error?(invoice_result)
        result.invoice = invoice_result.invoice
        # We want to send the webhook after the invoice is generated, because the job might have been scheduled multiple times
        passed_thresholds.each do |usage_threshold|
          SendWebhookJob.perform_later("subscription.usage_threshold_reached", subscription, usage_threshold:)
        end
      end

      result
    end

    private

    attr_reader :lifetime_usage
    delegate :subscription, to: :lifetime_usage

    def progressive_billed_amount
      Subscriptions::ProgressiveBilledAmount.call!(subscription:).progressive_billed_amount
    end

    def tax_error?(result)
      return false if result.success?

      result.error.is_a?(BaseService::UnknownTaxFailure)
    end
  end
end
