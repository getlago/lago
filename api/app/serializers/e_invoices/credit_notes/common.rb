# frozen_string_literal: true

module EInvoices
  module CreditNotes
    module Common
      def notes
        [
          "Credit Note ID: #{credit_note.id}",
          "Original Invoice: #{credit_note.invoice.number}",
          "Reason: #{credit_note.reason}"
        ]
      end

      def credits_and_payments(&block)
        yield EInvoices::BaseSerializer::STANDARD_PAYMENT, credit_note.credit_amount
      end

      def taxes(&block)
        resource.fees.group_by(&:taxes_rate).each do |tax_rate, fees|
          basis_amount = fees.flat_map(&:credit_note_items).sum(&:precise_amount_cents) - (allowances_per_tax_rate[tax_rate] || 0)
          tax_amount = basis_amount * tax_rate.fdiv(100)
          tax_category = tax_category_code(type: fees.first.fee_type, tax_rate: tax_rate)

          yield tax_category, tax_rate, Money.new(basis_amount), Money.new(tax_amount)
        end
      end

      def allowances
        credit_note.precise_coupons_adjustment_amount_cents
      end

      def allowances_per_tax_rate
        credit_note.items.each_with_object(Hash.new(0)) do |item, rates|
          item_fee_rate = item.fee.amount_cents.zero? ? 0 : item.precise_amount_cents.fdiv(item.fee.precise_amount_cents)
          rates[item.fee.taxes_rate] += item.fee.precise_coupons_amount_cents * item_fee_rate
        end
      end
    end
  end
end
