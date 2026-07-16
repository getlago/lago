# frozen_string_literal: true

module CreditNotes
  class CreateFromProgressiveBillingInvoice < BaseService
    Result = BaseResult[:credit_note]
    def initialize(progressive_billing_invoice:, amount:, reason: :other)
      @progressive_billing_invoice = progressive_billing_invoice
      @amount = amount
      @reason = reason

      super
    end

    def call
      return result unless amount.positive?
      return result.forbidden_failure! unless progressive_billing_invoice.progressive_billing?

      # Important to call this method as it modifies @amount if needed
      items = calculate_items!
      return result unless result.success?

      credit_amount_cents = creditable_amount_cents(amount, items)
      return result if credit_amount_cents.zero?

      credit_note_result = CreditNotes::CreateService.call!(
        invoice: progressive_billing_invoice,
        credit_amount_cents:,
        items:,
        reason:,
        automatic: true
      )

      result.credit_note = credit_note_result.credit_note
      result
    end

    private

    attr_reader :progressive_billing_invoice, :amount, :reason

    def calculate_items!
      items = []
      remaining = amount

      # The amount can be greater than a single fee amount. We'll keep on deducting until we've credited enough
      progressive_billing_invoice.fees.order(amount_cents: :desc).each do |fee|
        # no further credit remaining
        break if remaining.zero?

        # take the lower value of remaining or maximum creditable for this fee. (whichever is the lowest)
        fee_credit_amount = [remaining, fee.creditable_amount_cents].min
        items << {
          fee_id: fee.id,
          amount_cents: fee_credit_amount.truncate(CreditNote::DB_PRECISION_SCALE)
        }

        remaining -= fee_credit_amount
      end

      # it could be that we have some amount remaining due to multiple progressive billing invoices. This case should be handled manually
      # TODO(ProgressiveBilling): verify and check in v2
      if remaining.positive?
        result.not_allowed_failure!(code: "creditable_amount_is_less_than_requested")
      end

      items
    end

    def creditable_amount_cents(amount, items)
      taxes_result = CreditNotes::ApplyTaxesService.call(
        invoice: progressive_billing_invoice,
        items: items.map { |item| CreditNoteItem.new(fee_id: item[:fee_id], precise_amount_cents: item[:amount_cents]) }
      )

      (
        amount.truncate(CreditNote::DB_PRECISION_SCALE) -
        taxes_result.coupons_adjustment_amount_cents.truncate(CreditNote::DB_PRECISION_SCALE) +
        taxes_result.taxes_amount_cents.truncate(CreditNote::DB_PRECISION_SCALE)
      ).round
    end
  end
end
