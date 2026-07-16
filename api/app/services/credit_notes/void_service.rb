# frozen_string_literal: true

module CreditNotes
  class VoidService < BaseService
    Result = BaseResult[:credit_note]

    def initialize(credit_note:)
      @credit_note = credit_note

      super
    end

    def call
      return result.not_found_failure!(resource: "credit_note") if credit_note.nil? || credit_note.draft?

      result.credit_note = credit_note
      return result.not_allowed_failure!(code: "no_voidable_amount") unless credit_note.voidable?

      credit_note.mark_as_voided!

      result
    end

    private

    attr_reader :credit_note
  end
end
