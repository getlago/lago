# frozen_string_literal: true

module Integrations
  module Aggregator
    module Taxes
      module Invoices
        module Payloads
          class Avalara < BasePayload
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
                  "issuing_date" => invoice.issuing_date,
                  "currency" => invoice.currency,
                  "contact" => {
                    "external_id" => integration_customer&.external_customer_id,
                    "name" => customer.name,
                    "address_line_1" => shipping[:address_line1],
                    "city" => shipping[:city],
                    "zip" => shipping[:zipcode],
                    "region" => shipping[:state],
                    "country" => shipping[:country],
                    "taxable" => customer.tax_identification_number.present?,
                    "tax_number" => customer.tax_identification_number
                  },
                  "billing_entity" => {
                    "address_line_1" => billing_entity&.address_line1,
                    "city" => billing_entity&.city,
                    "zip" => billing_entity&.zipcode,
                    "region" => billing_entity&.state,
                    "country" => billing_entity&.country
                  },
                  "fees" => fees.map { |fee| fee_item(fee) }
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
                "unit" => fee.units,
                "amount" => item_amount(fee)
              }
            end

            private

            attr_reader :customer, :integration_customer, :invoice, :fees

            def empty_struct
              @empty_struct ||= OpenStruct.new
            end

            def item_amount(fee)
              amount = fee.sub_total_excluding_taxes_amount_cents&.to_i&.fdiv(subunit_to_unit(fee))

              amount *= -1 if invoice.voided?

              amount.to_s
            end

            def subunit_to_unit(fee)
              if fee.is_a?(Fee)
                fee.amount.currency.subunit_to_unit
              else
                amount_cents = fee.amount_cents || fee.sub_total_excluding_taxes_amount_cents
                Fee.new(amount_currency: invoice.currency, amount_cents:).amount.currency.subunit_to_unit
              end
            end
          end
        end
      end
    end
  end
end
