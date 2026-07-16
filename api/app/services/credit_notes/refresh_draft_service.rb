# frozen_string_literal: true

module CreditNotes
  class RefreshDraftService < BaseService
    Result = BaseResult[:credit_note]

    def initialize(credit_note:, fee:, old_fee_values:)
      @credit_note = credit_note
      @fee = fee
      @old_fee_values = old_fee_values

      super
    end

    def call
      result.credit_note = credit_note
      return result unless credit_note.draft?

      credit_note.applied_taxes.destroy_all
      credit_note.items.each do |item|
        item.fee_id = fee.id

        if old_fee_values.any?
          old_entry = old_fee_values.find { |h| h[:credit_note_item_id] == item.id }
          item.precise_amount_cents = calculate_item_value(item, old_entry[:fee_amount_cents]) if old_entry
        end

        item.save!
      end

      taxes_result = CreditNotes::ApplyTaxesService.call(
        invoice: fee.invoice,
        items: credit_note.items
      )

      credit_note.precise_coupons_adjustment_amount_cents = taxes_result.coupons_adjustment_amount_cents
      credit_note.coupons_adjustment_amount_cents = taxes_result.coupons_adjustment_amount_cents.round
      credit_note.precise_taxes_amount_cents = taxes_result.taxes_amount_cents
      credit_note.taxes_amount_cents = taxes_result.taxes_amount_cents.round
      credit_note.taxes_rate = taxes_result.taxes_rate

      taxes_result.applied_taxes.each { |applied_tax| credit_note.applied_taxes << applied_tax }

      credit_note.credit_amount_cents = (
        credit_note.items.sum(:precise_amount_cents).truncate(CreditNote::DB_PRECISION_SCALE) -
        taxes_result.coupons_adjustment_amount_cents +
        taxes_result.taxes_amount_cents
      ).round

      credit_note.balance_amount_cents = credit_note.credit_amount_cents
      credit_note.total_amount_cents = credit_note.credit_amount_cents + credit_note.refund_amount_cents

      CreditNotes::AdjustAmountsWithRoundingService.call!(credit_note:)
      credit_note.save!

      result
    end

    private

    attr_accessor :credit_note, :fee, :old_fee_values

    # NOTE: credit note item value needs to be recalculated based on the ratio between old fee value and
    #       new fee value
    def calculate_item_value(item, old_fee_amount_cents)
      return 0 if old_fee_amount_cents.zero?

      item.precise_amount_cents.fdiv(old_fee_amount_cents) * fee.amount_cents
    end
  end
end
