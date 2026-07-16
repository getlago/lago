# frozen_string_literal: true

module CreditNotes
  class ApplyTaxesService < BaseService
    Result = BaseResult[:applied_taxes, :coupons_adjustment_amount_cents, :precise_taxes_amount_cents, :taxes_amount_cents, :taxes_rate]

    def initialize(invoice:, items:)
      @invoice = invoice
      @items = items

      super
    end

    def call
      result.applied_taxes = []
      result.coupons_adjustment_amount_cents = coupons_adjustment_amount_cents

      applied_taxes_amount_cents = 0
      precise_applied_taxes_amount_cents = 0
      taxes_rate = 0

      indexed_items.each do |tax_code, _|
        invoice_applied_tax = find_invoice_applied_tax(tax_code)

        applied_tax = CreditNote::AppliedTax.new(
          organization_id: invoice.organization_id,
          tax: invoice_applied_tax.tax,
          tax_description: invoice_applied_tax.tax_description,
          tax_code: invoice_applied_tax.tax_code,
          tax_name: invoice_applied_tax.tax_name,
          tax_rate: invoice_applied_tax.tax_rate,
          amount_currency: invoice.currency
        )
        result.applied_taxes << applied_tax

        base_amount_cents = compute_base_amount_cents(tax_code)
        applied_tax.base_amount_cents = (base_amount_cents * taxes_base_rate(invoice_applied_tax)).round
        precise_base_amount_cents = (base_amount_cents * taxes_base_rate(invoice_applied_tax))
        precise_tax_amount_cents = (precise_base_amount_cents * invoice_applied_tax.tax_rate).fdiv(100)
        applied_tax.amount_cents += precise_tax_amount_cents.round

        precise_applied_taxes_amount_cents += precise_tax_amount_cents
        applied_taxes_amount_cents += precise_tax_amount_cents.round
        taxes_rate += pro_rated_taxes_rate(applied_tax)
      end

      result.precise_taxes_amount_cents = precise_applied_taxes_amount_cents
      result.taxes_amount_cents = applied_taxes_amount_cents
      result.taxes_rate = taxes_rate.round(5)

      result
    end

    private

    attr_reader :invoice, :items

    delegate :organization, to: :invoice

    # NOTE: indexes the credit note fees by taxes.
    #       Example output will be: { tax1 => [fee1, fee2], tax2 => [fee2] }
    def indexed_items
      @indexed_items ||= items.each_with_object({}) do |item, applied_taxes|
        item.fee.applied_taxes.each do |fee_applied_tax|
          applied_taxes[fee_applied_tax.tax_code] ||= []
          applied_taxes[fee_applied_tax.tax_code] << item
        end
      end
    end

    def items_amount_cents
      @items_amount_cents ||= items.sum(&:precise_amount_cents)
    end

    def coupons_adjustment_amount_cents
      return 0 if invoice.version_number < Invoice::COUPON_BEFORE_VAT_VERSION

      items.sum do |item|
        item_fee_rate = item.fee.amount_cents.zero? ? 0 : item.precise_amount_cents.fdiv(item.fee.amount_cents)
        item.fee.precise_coupons_amount_cents * item_fee_rate
      end
    end

    def compute_base_amount_cents(tax_code)
      indexed_items[tax_code].map do |item|
        # NOTE: Part of the item taken from the fee amount
        item_fee_rate = item.fee.amount_cents.zero? ? 0 : item.precise_amount_cents.fdiv(item.fee.amount_cents)

        # NOTE: Part of the coupons applied to the item
        prorated_coupon_amount = item.fee.precise_coupons_amount_cents * item_fee_rate

        item.precise_amount_cents - prorated_coupon_amount
      end.sum
    end

    # NOTE: Tax might not be applied to all items of the credit note.
    #       In order to compute the credit_note#taxes_rate, we have to apply
    #       a pro-rata of the items attached to the tax on the total items amount
    def pro_rated_taxes_rate(applied_tax)
      tax_items_amount_cents = compute_base_amount_cents(applied_tax.tax_code)
      total_items_amount_cents = items_amount_cents - result.coupons_adjustment_amount_cents

      items_rate = total_items_amount_cents.zero? ? 0 : tax_items_amount_cents.fdiv(total_items_amount_cents)

      items_rate * applied_tax.tax_rate
    end

    def find_invoice_applied_tax(tax_code)
      invoice.applied_taxes.find_by(tax_code: tax_code)
    end

    def taxes_base_rate(applied_tax)
      return 1 if applied_tax.fees_amount_cents.blank? || applied_tax.fees_amount_cents.zero?

      applied_tax.taxable_amount_cents.fdiv(applied_tax.fees_amount_cents)
    end
  end
end
