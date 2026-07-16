# frozen_string_literal: true

module CreditNotes
  class ValidateService < BaseValidator
    def valid?
      valid_invoice_status?
      valid_items_amount?
      valid_refund_amount?
      valid_credit_amount?
      valid_offset_amount?
      valid_remaining_invoice_amount?
      valid_total_amount_positive?

      if errors?
        result.validation_failure!(errors:)
        return false
      end

      true
    end

    private

    def credit_note
      args[:item]
    end

    delegate :invoice, to: :credit_note

    def total_amount_cents
      credit_note.credit_amount_cents +
        credit_note.refund_amount_cents +
        credit_note.offset_amount_cents
    end

    def creditable_amount_cents
      invoice.fee_total_amount_cents -
        credited_invoice_amount_cents -
        offset_amount_cents
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

    def precise_total_items_amount_cents
      (
        credit_note.items.sum(&:precise_amount_cents) -
          credit_note.precise_coupons_adjustment_amount_cents +
          credit_note.precise_taxes_amount_cents
      ).round
    end

    def valid_invoice_status?
      if credit_note.refund_amount_cents.positive?
        return true if invoice.payment_succeeded?

        if !invoice.payment_succeeded? &&
            invoice.total_paid_amount_cents == invoice.total_amount_cents && invoice.total_amount_cents > 0
          add_error(field: :refund_amount_cents, error_code: "cannot_refund_unpaid_invoice")

          return false
        end
      end

      true
    end

    def valid_invoice_type?
      return unless invoice.credit?

      add_error(field: :base, error_code: "cannot_credit_invoice")
      false
    end

    # NOTE: Check if total amount matched the items amount
    #       The comparison takes care of the rounding precision
    def valid_items_amount?
      return true if (total_amount_cents - precise_total_items_amount_cents).abs <= 1

      add_error(field: :base, error_code: "does_not_match_item_amounts")
    end

    # NOTE: Check if refunded amount is less than or equal to the invoice's paid amount
    def valid_refund_amount?
      return true if credit_note.refund_amount_cents.zero?

      if invoice.total_paid_amount_cents <= 0
        add_error(field: :refund_amount_cents, error_code: "cannot_refund_unpaid_invoice")
        return false
      end

      refundable_paid_cents = invoice.total_paid_amount_cents - refunded_invoice_amount_cents
      return true if credit_note.refund_amount_cents <= refundable_paid_cents

      add_error(field: :refund_amount_cents, error_code: "higher_than_remaining_invoice_amount")
    end

    # NOTE: Check if credited amount is less than or equal to invoice fee amount
    def valid_credit_amount?
      if invoice.credit? && credit_note.credit_amount_cents > 0
        add_error(field: :credit_amount_cents, error_code: "cannot_credit_invoice")
        return false
      end

      return true if credit_note.credit_amount_cents <= creditable_amount_cents

      if (credit_note.credit_amount_cents - creditable_amount_cents).abs > 1
        add_error(field: :credit_amount_cents, error_code: "higher_than_remaining_invoice_amount")
      end
    end

    def valid_offset_amount?
      return true if credit_note.offset_amount_cents.zero?
      return false unless valid_credit_invoice_application?

      invoice_due_amount_cents = invoice.total_amount_cents -
        invoice.total_paid_amount_cents -
        offset_amount_cents

      offsettable_amount = [invoice_due_amount_cents, creditable_amount_cents].min

      return true if credit_note.offset_amount_cents <= offsettable_amount

      add_error(field: :offset_amount_cents, error_code: "higher_than_remaining_invoice_amount")
    end

    def valid_credit_invoice_application?
      return true unless invoice.credit?

      if invoice.total_paid_amount_cents.positive?
        add_error(field: :offset_amount_cents, error_code: "cannot_apply_to_paid_invoice")
        return false
      end

      if credit_note.offset_amount_cents != invoice.total_amount_cents
        add_error(field: :offset_amount_cents, error_code: "not_equal_to_total_amount")
        return false
      end

      true
    end

    # NOTE: Check if total amount is less than or equal to invoice fee amount
    def valid_remaining_invoice_amount?
      remaining = invoice.fee_total_amount_cents - invoice_credit_note_total_amount_cents
      return true if total_amount_cents <= remaining

      if (total_amount_cents - remaining).abs > 1
        add_error(field: :base, error_code: "higher_than_remaining_invoice_amount")
      end
    end

    # NOTE: Check if total amount is greater than 0
    def valid_total_amount_positive?
      return true if total_amount_cents > 0

      add_error(field: :base, error_code: "total_amount_must_be_positive")
    end
  end
end
