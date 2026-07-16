# frozen_string_literal: true

module Integrations
  module Aggregator
    module Invoices
      module Payloads
        class Hubspot < BasePayload
          def create_body
            unless invoice.file_url
              raise Integrations::Aggregator::BasePayload::Failure.new(nil, code: "invoice.file_url missing")
            end

            {
              "objectType" => integration.invoices_object_type_id,
              "input" => {
                "associations" => [],
                "properties" => {
                  "lago_invoice_id" => invoice.id,
                  "lago_invoice_number" => invoice.number,
                  "lago_invoice_purchase_order_number" => invoice.purchase_order_number,
                  "lago_invoice_issuing_date" => formatted_date(invoice.issuing_date),
                  "lago_invoice_payment_due_date" => formatted_date(invoice.payment_due_date),
                  "lago_invoice_payment_overdue" => invoice.payment_overdue,
                  "lago_invoice_type" => invoice.invoice_type,
                  "lago_invoice_status" => invoice.status,
                  "lago_invoice_payment_status" => invoice.payment_status,
                  "lago_invoice_currency" => invoice.currency,
                  "lago_invoice_total_amount" => total_amount,
                  "lago_invoice_total_due_amount" => total_due_amount,
                  "lago_invoice_subtotal_excluding_taxes" => subtotal_excluding_taxes,
                  "lago_invoice_file_url" => invoice.file_url,
                  "lago_invoice_url" => invoice_url
                }
              }
            }
          end

          def update_body
            unless invoice.file_url
              raise Integrations::Aggregator::BasePayload::Failure.new(nil, code: "invoice.file_url missing")
            end

            {
              "objectId" => integration_invoice.external_id,
              "objectType" => integration.invoices_object_type_id,
              "input" => {
                "properties" => {
                  "lago_invoice_id" => invoice.id,
                  "lago_invoice_number" => invoice.number,
                  "lago_invoice_purchase_order_number" => invoice.purchase_order_number,
                  "lago_invoice_issuing_date" => formatted_date(invoice.issuing_date),
                  "lago_invoice_payment_due_date" => formatted_date(invoice.payment_due_date),
                  "lago_invoice_payment_overdue" => invoice.payment_overdue,
                  "lago_invoice_type" => invoice.invoice_type,
                  "lago_invoice_status" => invoice.status,
                  "lago_invoice_payment_status" => invoice.payment_status,
                  "lago_invoice_currency" => invoice.currency,
                  "lago_invoice_total_amount" => total_amount,
                  "lago_invoice_total_due_amount" => total_due_amount,
                  "lago_invoice_subtotal_excluding_taxes" => subtotal_excluding_taxes,
                  "lago_invoice_file_url" => invoice.file_url,
                  "lago_invoice_url" => invoice_url
                }
              }
            }
          end

          def customer_association_body
            {
              "objectType" => integration.reload.invoices_object_type_id,
              "objectId" => integration_invoice.external_id,
              "toObjectType" => integration_customer.object_type,
              "toObjectId" => integration_customer.external_customer_id,
              "input" => []
            }
          end

          private

          def total_amount
            amount(invoice.total_amount_cents, resource: invoice)
          end

          def total_due_amount
            amount(invoice.total_due_amount_cents, resource: invoice)
          end

          def subtotal_excluding_taxes
            amount(invoice.sub_total_excluding_taxes_amount_cents, resource: invoice)
          end
        end
      end
    end
  end
end
