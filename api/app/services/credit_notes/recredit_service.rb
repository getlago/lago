# frozen_string_literal: true

module CreditNotes
  class RecreditService < BaseService
    Result = BaseResult[:credit_note]

    def initialize(credit:)
      @credit = credit
      @credit_note = credit.credit_note

      super
    end

    def call
      return result.not_found_failure!(resource: "credit_note") if credit_note.nil?
      return result.not_allowed_failure!(code: "credit_note_voided") if credit_note.voided?

      result.credit_note = credit_note

      credit_note.balance_amount_cents += credit.amount_cents
      credit_note.credit_status = :available
      credit_note.save!

      result
    end

    private

    attr_reader :credit, :credit_note
  end
end
