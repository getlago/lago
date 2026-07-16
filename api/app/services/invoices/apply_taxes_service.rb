# frozen_string_literal: true

module Invoices
  class ApplyTaxesService < BaseService
    Result = BaseResult[:applied_taxes, :invoice]

    def initialize(invoice:)
      @invoice = invoice

      super
    end

    def call
      result.applied_taxes = []
      applied_taxes_amount_cents = 0
      taxes_rate = 0

      applicable_taxes.each do |tax|
        applied_tax = invoice.applied_taxes.new(
          organization:,
          tax:,
          tax_description: tax.description,
          tax_code: tax.code,
          tax_name: tax.name,
          tax_rate: tax.rate,
          amount_currency: invoice.currency
        )
        invoice.applied_taxes << applied_tax

        tax_amount_cents = compute_tax_amount_cents(tax)
        applied_tax.fees_amount_cents = fees_amount_cents(tax)
        applied_tax.amount_cents = tax_amount_cents.round

        # NOTE: when applied on user current usage, the invoice is
        #       not created in DB
        applied_tax.save! if invoice.persisted?

        applied_taxes_amount_cents += tax_amount_cents
        taxes_rate += pro_rated_taxes_rate(tax)

        result.applied_taxes << applied_tax
      end

      invoice.taxes_amount_cents = applied_taxes_amount_cents.round
      invoice.taxes_rate = taxes_rate.round(5)
      result.invoice = invoice

      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    end

    private

    attr_reader :invoice

    delegate :organization, to: :invoice

    # Note: taxes, applied on the fees might be created on organization, but selected for specific add-on, for example
    # so not applied on the billing_entity
    def applicable_taxes
      organization.taxes.where(id: indexed_fees.keys)
    end

    # NOTE: indexes the invoice fees by taxes.
    #       Example output will be: { tax1 => [fee1, fee2], tax2 => [fee2] }
    def indexed_fees
      @indexed_fees ||= invoice.fees.each_with_object({}) do |fee, applied_taxes|
        fee.applied_taxes.each do |applied_tax|
          applied_taxes[applied_tax.tax_id] ||= []
          applied_taxes[applied_tax.tax_id] << fee
        end
      end
    end

    # NOTE: Because coupons are applied before VAT,
    #       we have to take the coupons amount pro-rated at fee level into account
    def compute_tax_amount_cents(tax)
      indexed_fees[tax.id]
        .sum { |fee| fee.sub_total_excluding_taxes_amount_cents * tax.rate }
        .fdiv(100)
    end

    # NOTE: Tax might not be applied to all fees of the invoice.
    #       In order to compute the invoice#taxes_rate, we have to apply
    #       a pro-rata of the fees attached to the tax on the invoices#fees_amount_cents
    def pro_rated_taxes_rate(tax)
      fees_rate = if invoice.sub_total_excluding_taxes_amount_cents.positive?
        fees_amount_cents(tax).fdiv(invoice.sub_total_excluding_taxes_amount_cents)
      else
        # NOTE: when invoice have a 0 amount. The prorata is on the number of fees
        indexed_fees[tax.id].count.fdiv(invoice.fees.length)
      end

      fees_rate * tax.rate
    end

    def fees_amount_cents(tax)
      indexed_fees[tax.id].sum(&:sub_total_excluding_taxes_amount_cents)
    end
  end
end
