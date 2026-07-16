# frozen_string_literal: true

module CreditNotes
  module ProviderTaxes
    class ReportJob < ApplicationJob
      queue_as "integrations"

      def perform(credit_note:)
        return if credit_note.invoice.credit?
        return unless credit_note.customer.tax_customer

        # NOTE: We don't want to raise error here.
        #       If sync fails, invoice would be marked and retry option would be available in the UI
        CreditNotes::ProviderTaxes::ReportService.call(credit_note:)
      end
    end
  end
end
