# frozen_string_literal: true

module Invoices
  class ComputeAmountsFromFees < BaseService
    Result = BaseResult[:invoice]

    def initialize(invoice:, provider_taxes: nil)
      @invoice = invoice
      @provider_taxes = provider_taxes

      super
    end

    def call
      if should_apply_fee_taxes?
        invoice.fees.each do |fee|
          if should_apply_provider_taxes?
            Fees::ApplyProviderTaxesService.call!(fee:, fee_taxes: fee_taxes(fee))
          else
            Fees::ApplyTaxesService.call!(fee:)
          end

          fee.save! if invoice.persisted?
        end
      end

      invoice.fees_amount_cents = invoice.fees.sum(&:amount_cents)
      invoice.coupons_amount_cents = invoice.credits.coupon_kind.sum(&:amount_cents)

      invoice.sub_total_excluding_taxes_amount_cents = (
        invoice.fees_amount_cents - invoice.progressive_billing_credit_amount_cents - invoice.coupons_amount_cents
      )

      if should_apply_provider_taxes?
        Invoices::ApplyProviderTaxesService.call!(invoice:, provider_taxes:)
      else
        Invoices::ApplyTaxesService.call!(invoice:)
      end

      invoice.sub_total_including_taxes_amount_cents = (
        invoice.sub_total_excluding_taxes_amount_cents + invoice.taxes_amount_cents
      )
      invoice.total_amount_cents = (
        invoice.sub_total_including_taxes_amount_cents - invoice.credit_notes_amount_cents
      )

      result.invoice = invoice
      result
    end

    private

    attr_reader :invoice, :provider_taxes

    def should_apply_provider_taxes?
      provider_taxes && customer_provider_taxation? && invoice.should_apply_provider_tax?
    end

    def customer_provider_taxation?
      @customer_provider_taxation ||= invoice.customer.tax_customer
    end

    def fee_taxes(fee)
      provider_taxes.find { |item| item.item_id == fee.id }
    end

    def should_apply_fee_taxes?
      return false if invoice.advance_charges?

      true
    end
  end
end
