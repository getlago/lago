# frozen_string_literal: true

module CreditNotes
  class RecreditJob < ApplicationJob
    queue_as "default"

    def perform(credit)
      credit_note = credit.credit_note
      return if credit_note.nil? || credit_note.voided?

      CreditNotes::RecreditService.call!(credit:)
    end
  end
end
