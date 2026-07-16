# frozen_string_literal: true

module Integrations
  module Aggregator
    module Taxes
      module Invoices
        class BaseService < Integrations::Aggregator::Taxes::BaseService
          def initialize(invoice:, fees: nil)
            @invoice = invoice
            @fees = fees || invoice.fees

            super()
          end

          private

          attr_reader :invoice, :fees

          delegate :customer, to: :invoice, allow_nil: true

          def process_void_response(body)
            invoice_id = body["succeededInvoices"]&.first.try(:[], "id")

            if invoice_id
              result.invoice_id = invoice_id
            else
              code, message = retrieve_error_details(body["failedInvoices"].first["validation_errors"])

              raise Integrations::Aggregator::OutOfMemoryError if message.include?(OUT_OF_MEMORY_ERROR)
              raise Integrations::Aggregator::ServerContentionError, message if server_contention_error?(message)

              deliver_tax_error_webhook(customer:, code:, message:)
              result.service_failure!(code:, message:)
            end
          end
        end
      end
    end
  end
end
