# frozen_string_literal: true

module CreditNotes
  class GeneratePdfJob < ApplicationJob
    queue_as "invoices"

    def perform(credit_note)
      result = CreditNotes::GeneratePdfService.call(credit_note:, context: "api")
      result.raise_if_error!
    end
  end
end
