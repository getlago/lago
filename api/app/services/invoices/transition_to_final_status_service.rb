# frozen_string_literal: true

module Invoices
  class TransitionToFinalStatusService < BaseService
    Result = BaseResult[:invoice]

    def initialize(invoice:)
      @invoice = invoice
      @customer = @invoice.customer
      @billing_entity = @invoice.billing_entity
      super
    end

    def call
      result.invoice = invoice

      # Keep open for payment-gated invoices awaiting payment or tax resolution.
      # Tax pending matters because totals are not yet computed — falling through
      # would treat the invoice as zero-amount and finalize it prematurely.
      return result if invoice.subscription_gated? && (invoice.total_amount_cents.positive? || invoice.tax_pending?)

      if should_finalize_invoice?
        Invoices::FinalizeService.call!(invoice: invoice)
      else
        invoice.status = :closed
      end

      result
    end

    def should_finalize_invoice?
      return true unless invoice.fees_amount_cents.zero?
      customer_setting = customer.finalize_zero_amount_invoice
      if customer_setting == "inherit"
        billing_entity.finalize_zero_amount_invoice
      else
        customer_setting == "finalize"
      end
    end

    private

    attr_reader :invoice, :customer, :billing_entity
  end
end
