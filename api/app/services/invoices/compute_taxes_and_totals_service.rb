# frozen_string_literal: true

module Invoices
  class ComputeTaxesAndTotalsService < BaseService
    Result = BaseResult[:invoice, :non_invoiceable_fees]

    def initialize(invoice:, finalizing: true)
      @invoice = invoice
      @finalizing = finalizing

      super
    end

    def call
      return result.not_found_failure!(resource: "invoice") unless invoice

      # Tax provider takes precedence - VIES is irrelevant for these customers
      if customer_provider_taxation? && invoice.should_apply_provider_tax?
        set_pending_tax_status!
        after_commit { Invoices::ProviderTaxes::PullTaxesAndApplyJob.perform_later(invoice:) }
        return result.unknown_tax_failure!(code: "tax_error", message: "unknown taxes")
      end

      vies_result = Invoices::EnsureCompletedViesCheckService.call(invoice:, finalizing:)
      return vies_result if vies_result.failure?

      # Apply local taxes
      Invoices::ComputeAmountsFromFees.call(invoice:)

      result.invoice = invoice
      result
    end

    private

    attr_reader :invoice, :finalizing

    def set_pending_tax_status!
      invoice.status = (invoice.subscription_gated? ? :open : :pending) if finalizing
      invoice.tax_status = :pending
      invoice.save!
    end

    def customer_provider_taxation?
      @customer_provider_taxation ||= invoice.customer.tax_customer
    end
  end
end
