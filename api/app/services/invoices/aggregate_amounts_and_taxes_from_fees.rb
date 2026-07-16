# frozen_string_literal: true

module Invoices
  class AggregateAmountsAndTaxesFromFees < BaseService
    Result = BaseResult[:invoice]

    def initialize(invoice:)
      @invoice = invoice

      super
    end

    # NOTE: progressive billing, coupons and credit notes are not supported here
    def call
      unless invoice.advance_charges?
        return result.service_failure!(code: "invalid_invoice", message: "type of invoice must be `advance_charges`")
      end

      result.invoice = invoice
      return result if invoice.fees.empty?

      invoice.fees_amount_cents = invoice.fees.sum(&:amount_cents)
      invoice.taxes_amount_cents = invoice.fees.sum(&:taxes_amount_cents)
      invoice.total_amount_cents = invoice.fees_amount_cents + invoice.taxes_amount_cents
      invoice.sub_total_excluding_taxes_amount_cents = invoice.fees_amount_cents
      invoice.sub_total_including_taxes_amount_cents = invoice.sub_total_excluding_taxes_amount_cents + invoice.taxes_amount_cents

      # Note: This field is populated for consistency but probably shouldn't be use
      invoice.taxes_rate = if invoice.fees_amount_cents.zero?
        0
      else
        (invoice.taxes_amount_cents.to_f * 100 / invoice.fees_amount_cents).round(2)
      end

      invoice.applied_taxes = invoice.fees.includes(:applied_taxes).flat_map(&:applied_taxes).group_by(&:tax_id).map do |tax_id, applied_taxes|
        t = applied_taxes.first
        Invoice::AppliedTax.new(
          organization: invoice.organization,
          tax_id: tax_id,
          tax_name: t.tax_name,
          tax_code: t.tax_code,
          tax_description: t.tax_description,
          tax_rate: t.tax_rate,
          amount_currency: t.amount_currency,

          amount_cents: applied_taxes.sum(&:amount_cents),
          fees_amount_cents: applied_taxes.sum { |at| at.fee.sub_total_excluding_taxes_amount_cents },
          taxable_base_amount_cents: applied_taxes.sum { |at| at.fee.taxes_base_rate * at.fee.sub_total_excluding_taxes_amount_cents }
        )
      end

      result
    end

    private

    attr_reader :invoice
  end
end
