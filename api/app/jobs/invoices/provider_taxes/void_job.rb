# frozen_string_literal: true

module Invoices
  module ProviderTaxes
    class VoidJob < ApplicationJob
      queue_as "integrations"

      def perform(invoice:)
        return unless invoice.customer.tax_customer

        # NOTE: We don't want to raise error here.
        #       If sync fails, invoice would be marked and retry option would be available in the UI
        Invoices::ProviderTaxes::VoidService.call(invoice:)
      end
    end
  end
end
