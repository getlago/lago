# frozen_string_literal: true

module CreditNotes
  class ValidateItemService < BaseValidator
    def valid?
      return false unless valid_fee?

      valid_item_amount?
      valid_individual_amount?

      if errors?
        result.validation_failure!(errors:)
        return false
      end

      true
    end

    private

    def item
      args[:item]
    end

    delegate :credit_note, :fee, to: :item
    delegate :invoice, to: :credit_note

    def credited_fee_amount_cents
      fee.credit_note_items.sum(:amount_cents)
    end

    def refunded_invoice_amount_cents
      invoice.credit_notes.finalized.where.not(id: credit_note.id).sum(:refund_amount_cents)
    end

    def credited_invoice_amount_cents
      invoice.credit_notes.finalized.where.not(id: credit_note.id).sum(:credit_amount_cents)
    end

    def offset_amount_cents
      invoice.credit_notes.finalized.where.not(id: credit_note.id).sum(:offset_amount_cents)
    end

    def invoice_credit_note_total_amount_cents
      credited_invoice_amount_cents + refunded_invoice_amount_cents + offset_amount_cents
    end

    def total_item_amount_cents
      (item.amount_cents + (item.amount_cents * fee.taxes_rate).fdiv(100)).round
    end

    def valid_fee?
      return true if item.fee.present?

      result.not_found_failure!(resource: "fee")

      false
    end

    # NOTE: Check if item amount is not negative
    def valid_item_amount?
      return true unless item.amount_cents.negative?

      add_error(field: :amount_cents, error_code: "invalid_value")
    end

    # NOTE: Check if item amount is less than or equal to fee remaining creditable amount
    def valid_individual_amount?
      return true if item.amount_cents <= fee.creditable_amount_cents
      return true if prepaid_credit_invoice? && (invoice.payment_pending? || invoice.payment_failed?)

      if prepaid_credit_invoice? && wallet_balance_insufficient?
        add_error(field: :amount_cents, error_code: "higher_than_wallet_balance")
      else
        add_error(field: :amount_cents, error_code: "higher_than_remaining_fee_amount")
      end
    end

    def prepaid_credit_invoice?
      invoice.credit?
    end

    def wallet_balance_insufficient?
      item.amount_cents > invoice.prepaid_credit_fee.creditable_from_wallet_amount_cents
    end

    # NOTE: Check if item amount is less than or equal to invoice remaining creditable amount
    def valid_global_amount?
      return true if total_item_amount_cents <= invoice.fee_total_amount_cents - invoice_credit_note_total_amount_cents

      add_error(field: :amount_cents, error_code: "higher_than_remaining_invoice_amount")
    end
  end
end
