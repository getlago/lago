# frozen_string_literal: true

module Integrations
  module Salesforce
    module Invoices
      class SyncService < BaseService
        def initialize(invoice)
          @invoice = invoice

          super
        end

        def call
          return result.not_found_failure!(resource: "invoice") unless invoice
          SendWebhookJob.perform_later("invoice.resynced", invoice)
          result.invoice_id = invoice.id
          result
        end

        private

        attr_reader :invoice
      end
    end
  end
end
