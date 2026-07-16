# frozen_string_literal: true

module Integrations
  module Aggregator
    module Taxes
      module Invoices
        module Payloads
          class Anrok < BasePayload
            def initialize(integration:, customer:, invoice:, integration_customer:, fees: [])
              super(integration:, billing_entity: customer.billing_entity)

              @customer = customer
              @integration_customer = integration_customer
              @invoice = invoice
              @fees = fees
            end

            def body
              shipping = customer.effective_shipping_address

              [
                {
                  "issuing_date" => issuing_date,
                  "currency" => invoice.currency,
                  "contact" => {
                    "external_id" => integration_customer&.external_customer_id || customer.external_id,
                    "name" => customer.name,
                    "address_line_1" => shipping[:address_line1],
                    "city" => shipping[:city],
                    "zip" => shipping[:zipcode],
                    "country" => shipping[:country],
                    "taxable" => customer.tax_identification_number.present?,
                    "tax_number" => customer.tax_identification_number
                  },
                  "fees" => fees.map { |fee| fee_item(fee) },
                  "tax_date" => issuing_date
                }
              ]
            end

            def fee_item(fee)
              mapped_item = if fee.charge?
                billable_metric_item(fee)
              elsif fee.add_on_id.present?
                add_on_item(fee)
              elsif fee.fixed_charge?
                fixed_charge_item(fee)
              elsif fee.commitment?
                commitment_item
              elsif fee.subscription?
                subscription_item
              end
              mapped_item ||= empty_struct

              {
                "item_key" => fee.item_key,
                "item_id" => fee.id || fee.item_id,
                "item_code" => mapped_item.external_id,
                "amount_cents" => fee.sub_total_excluding_taxes_amount_cents&.to_i
              }
            end

            private

            attr_reader :customer, :integration_customer, :invoice, :fees

            def empty_struct
              @empty_struct ||= OpenStruct.new
            end

            def issuing_date
              # NOTE: Anrok API requires issuing date to be 30 days in the future at  most.
              [invoice.issuing_date, 30.days.from_now.to_date].min
            end
          end
        end
      end
    end
  end
end
