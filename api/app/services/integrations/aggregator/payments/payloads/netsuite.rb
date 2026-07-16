# frozen_string_literal: true

module Integrations
  module Aggregator
    module Payments
      module Payloads
        class Netsuite < BasePayload
          def body
            {
              "isDynamic" => true,
              "columns" => {
                "customer" => integration_customer.external_customer_id,
                "payment" => amount(payment.amount_cents, resource: invoice)
              },
              "options" => {
                "ignoreMandatoryFields" => false
              },
              "type" => "customerpayment",
              "lines" => [
                {
                  "lineItems" => [
                    {
                      "amount" => amount(payment.amount_cents, resource: invoice),
                      "apply" => true,
                      "doc" => integration_invoice.external_id
                    }
                  ],
                  "sublistId" => "apply"
                }
              ]
            }
          end
        end
      end
    end
  end
end
