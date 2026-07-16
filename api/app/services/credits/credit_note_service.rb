# frozen_string_literal: true

module Credits
  class CreditNoteService < BaseService
    Result = BaseResult[:credits]

    def initialize(invoice:, context: nil)
      @invoice = invoice
      @context = context

      super(nil)
    end

    def call
      return result if already_applied?

      result.credits = []

      if context == :preview
        apply_credits
      else
        ActiveRecord::Base.transaction do
          CreditNotes::LockService.new(customer:).call do
            apply_credits
          end
        end
      end

      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    end

    private

    attr_accessor :invoice, :context

    delegate :customer, to: :invoice

    def apply_credits
      remaining_invoice_amount = invoice.total_amount_cents

      credit_notes.each do |credit_note|
        credit_note.reload unless context == :preview

        credit_amount = compute_credit_amount(credit_note, remaining_invoice_amount)
        next unless credit_amount.positive?

        # NOTE: create a new credit line on the invoice
        credit = Credit.new(
          organization_id: invoice.organization_id,
          invoice:,
          credit_note:,
          amount_cents: credit_amount,
          amount_currency: invoice.currency,
          before_taxes: false
        )
        credit.save! unless context == :preview

        apply_credit_to_fees(credit, remaining_invoice_amount) unless context == :preview

        # NOTE: Consume remaining credit on the credit note
        update_remaining_credit(credit_note, credit_amount) unless context == :preview
        remaining_invoice_amount -= credit_amount

        result.credits << credit
        invoice.credit_notes_amount_cents += credit.amount_cents

        # NOTE: Invoice amount is fully covered by the credit notes
        break if remaining_invoice_amount.zero?
      end
    end

    def credit_notes
      customer.credit_notes
        .finalized
        .available
        .where(total_amount_currency: invoice.currency)
        .where.not(invoice_id: invoice.id)
        .order(created_at: :asc)
        .to_a
    end

    def already_applied?
      invoice.credits.where.not(credit_note_id: nil).exists?
    end

    def compute_credit_amount(credit_note, remaining_invoice_amount)
      if credit_note.balance_amount_cents > remaining_invoice_amount
        remaining_invoice_amount
      else
        credit_note.balance_amount_cents
      end
    end

    def update_remaining_credit(credit_note, consumed_credit)
      credit_note.update!(
        balance_amount_cents: credit_note.balance_amount_cents - consumed_credit
      )

      credit_note.consumed! if credit_note.balance_amount_cents.zero?
    end

    def apply_credit_to_fees(credit, remaining_invoice_amount)
      invoice.fees.reload.each do |fee|
        fee_amount_after_tax = fee.amount_cents - fee.precise_coupons_amount_cents + fee.taxes_amount_cents

        fee.precise_credit_notes_amount_cents += (
          credit.amount_cents * (fee_amount_after_tax - fee.precise_credit_notes_amount_cents)
        ).fdiv(remaining_invoice_amount)

        fee.precise_credit_notes_amount_cents = fee_amount_after_tax if fee_amount_after_tax < fee.precise_credit_notes_amount_cents
        fee.save!
      end
    end
  end
end
