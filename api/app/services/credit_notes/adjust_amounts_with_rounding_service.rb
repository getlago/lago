# frozen_string_literal: true

module CreditNotes
  class AdjustAmountsWithRoundingService < BaseService
    Result = BaseResult[:credit_note]

    def initialize(credit_note:)
      @credit_note = credit_note

      super
    end

    # NOTE: The goal of this service is to adjust the amounts so
    #       that sub total excluding taxes + taxes amount = total amount
    #       taking the rounding into account
    def call
      subtotal = credit_note.total_amount_cents - credit_note.taxes_amount_cents

      if subtotal != credit_note.sub_total_excluding_taxes_amount_cents
        if subtotal > credit_note.sub_total_excluding_taxes_amount_cents
          credit_note.total_amount_cents -= 1
        else
          credit_note.total_amount_cents += 1
        end

        if credit_note.credit_amount_cents > 0
          # NOTE: Adjust credit_amount_cents to make sure that we keep
          #       total_amount_cents = credit_amount_cents + refund_amount_cents
          credit_note.credit_amount_cents = credit_note.total_amount_cents - credit_note.refund_amount_cents
        else
          credit_note.refund_amount_cents = credit_note.total_amount_cents
        end

        credit_note.balance_amount_cents = credit_note.credit_amount_cents
      end

      result.credit_note = credit_note
      result
    end

    private

    attr_reader :credit_note
  end
end
