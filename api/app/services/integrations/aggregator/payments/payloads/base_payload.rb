# frozen_string_literal: true

module Integrations
  module Aggregator
    module Payments
      module Payloads
        class BasePayload < Integrations::Aggregator::BasePayload
          def initialize(integration:, payment:)
            super(integration:, billing_entity: payment.payable.customer.billing_entity)

            @payment = payment
          end

          def body
            [
              {
                "invoice_id" => integration_invoice.external_id,
                "account_code" => account_item&.external_account_code,
                "date" => payment.created_at.utc.iso8601,
                "amount_cents" => payment.amount_cents
              }
            ]
          end

          def integration_payment
            @integration_payment ||=
              IntegrationResource.find_by(integration:, syncable: payment, resource_type: "payment")
          end

          private

          attr_reader :payment

          def invoice
            payment.payable
          end

          def integration_invoice
            integration_resource =
              invoice.integration_resources
                .where(integration:, resource_type: "invoice", syncable_type: "Invoice").first

            unless integration_resource
              raise Integrations::Aggregator::BasePayload::Failure.new(nil, code: "invoice_missing")
            end

            integration_resource
          end

          def integration_customer
            @integration_customer ||= invoice.customer&.integration_customers&.accounting_kind&.first
          end
        end
      end
    end
  end
end
