# frozen_string_literal: true

module CreditNotes
  class EstimateService < BaseService
    Result = BaseResult[:credit_note]

    def initialize(invoice:, items:)
      @invoice = invoice
      @items = items

      super
    end

    def call
      return result.not_found_failure!(resource: "invoice") unless invoice
      return result.forbidden_failure! unless License.premium?
      return result.not_allowed_failure!(code: "invalid_type_or_status") unless valid_type_or_status?

      @credit_note = CreditNote.new(
        organization_id: invoice.organization_id,
        customer: invoice.customer,
        invoice:,
        total_amount_currency: invoice.currency,
        credit_amount_currency: invoice.currency,
        refund_amount_currency: invoice.currency,
        balance_amount_currency: invoice.currency
      )

      validate_items
      return result unless result.success?

      compute_amounts_and_taxes
      adjust_amounts_with_rounding

      result.credit_note = credit_note
      result
    end

    private

    attr_reader :invoice, :items, :credit_note

    def valid_type_or_status?
      return false if invoice.credit? && (invoice.payment_status != "succeeded" || invoice.associated_active_wallet.nil?)

      invoice.version_number >= Invoice::CREDIT_NOTES_MIN_VERSION
    end

    def validate_items
      return result.validation_failure!(errors: {items: ["must_be_an_array"]}) unless items.is_a?(Array)

      items.each do |item_attr|
        amount_cents = item_attr[:amount_cents]&.to_i || 0

        item = CreditNoteItem.new(
          organization_id: invoice.organization_id,
          fee: invoice.fees.find_by(id: item_attr[:fee_id]),
          amount_cents: amount_cents.round,
          precise_amount_cents: amount_cents,
          amount_currency: invoice.currency
        )
        credit_note.items << item

        break unless valid_item?(item)
      end
    end

    def valid_credit_note?
      CreditNotes::ValidateService.new(result, item: credit_note).valid?
    end

    def valid_item?(item)
      CreditNotes::ValidateItemService.new(result, item:).valid?
    end

    def compute_amounts_and_taxes
      taxes_result = CreditNotes::ApplyTaxesService.call(
        invoice:,
        items: credit_note.items
      )

      credit_note.precise_coupons_adjustment_amount_cents = taxes_result.coupons_adjustment_amount_cents
      credit_note.coupons_adjustment_amount_cents = taxes_result.coupons_adjustment_amount_cents.round
      credit_note.precise_taxes_amount_cents = taxes_result.precise_taxes_amount_cents
      adjust_credit_note_tax_precise_rounding if credit_note_for_all_remaining_amount?

      credit_note.taxes_amount_cents = credit_note.precise_taxes_amount_cents.round
      credit_note.taxes_rate = taxes_result.taxes_rate

      taxes_result.applied_taxes.each { |applied_tax| credit_note.applied_taxes << applied_tax }

      credit_note.credit_amount_cents = compute_creditable_amount(taxes_result)
      compute_refundable_amount

      credit_note.credit_amount_cents = 0 if invoice.credit?
      credit_note.total_amount_cents = credit_note.credit_amount_cents
    end

    def credit_note_for_all_remaining_amount?
      credit_note.items.sum(&:precise_amount_cents) == credit_note.invoice.fees.sum(&:creditable_amount_cents)
    end

    def adjust_credit_note_tax_precise_rounding
      credit_note.precise_taxes_amount_cents -= all_rounding_tax_adjustments
    end

    def all_rounding_tax_adjustments
      credit_note.invoice.credit_notes.sum(&:taxes_rounding_adjustment)
    end

    def compute_creditable_amount(taxes_result)
      (
        credit_note.items.sum(&:amount_cents) -
        taxes_result.coupons_adjustment_amount_cents +
        credit_note.precise_taxes_amount_cents
      ).round
    end

    def compute_refundable_amount
      credit_note.refund_amount_cents = credit_note.credit_amount_cents

      refundable_amount_cents = invoice.refundable_amount_cents
      return unless credit_note.credit_amount_cents > refundable_amount_cents

      credit_note.refund_amount_cents = refundable_amount_cents
    end

    # NOTE: The goal of this method is to adjust the amounts so
    #       that sub total exluding taxes + taxes amount = total amount
    #       taking the rounding into account
    def adjust_amounts_with_rounding
      subtotal = credit_note.total_amount_cents - credit_note.taxes_amount_cents

      if subtotal != credit_note.sub_total_excluding_taxes_amount_cents
        if subtotal > credit_note.sub_total_excluding_taxes_amount_cents
          credit_note.total_amount_cents -= 1
        elsif credit_note.taxes_amount_cents > 0
          credit_note.taxes_amount_cents -= 1
        end

        credit_note.credit_amount_cents = credit_note.total_amount_cents
        credit_note.balance_amount_cents = credit_note.credit_amount_cents
      end
    end
  end
end
