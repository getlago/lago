# frozen_string_literal: true

module Integrations
  module Aggregator
    module Invoices
      module Payloads
        class BasePayload < Integrations::Aggregator::BasePayload
          def initialize(integration_customer:, invoice:)
            super(integration: integration_customer.integration, billing_entity: integration_customer.customer.billing_entity)

            @invoice = invoice
            @integration_customer = integration_customer
          end

          def body
            [
              {
                "external_contact_id" => integration_customer.external_customer_id,
                "status" => "AUTHORISED",
                "issuing_date" => invoice.issuing_date.to_time.utc.iso8601,
                "payment_due_date" => invoice.payment_due_date.to_time.utc.iso8601,
                "number" => invoice.number,
                "currency" => invoice.currency,
                "type" => "ACCREC",
                "fees" => (tax_adjusted_fee_items + discounts)
              }
            ]
          end

          def integration_invoice
            @integration_invoice ||=
              IntegrationResource.find_by(integration:, syncable: invoice, resource_type: "invoice")
          end

          private

          attr_reader :integration_customer, :invoice
          attr_accessor :remaining_taxes_amount_cents

          def fees
            @fees ||= if invoice.fees.where("amount_cents > ?", 0).exists?
              invoice.fees.where("amount_cents > ?", 0).order(created_at: :asc)
            else
              invoice.fees.order(created_at: :asc)
            end
          end

          def fee_items
            fees.map { |fee| item(fee) }
          end

          def tax_adjusted_fee_items
            remaining_taxes_amount_cents = invoice.taxes_amount_cents - fee_items.sum { |f| f["taxes_amount_cents"] }.round

            fee_items.map do |fee|
              # If no coupon fix the tax rounding issue here
              if remaining_taxes_amount_cents.to_i.abs > 0 &&
                  invoice.coupons_amount_cents == 0 &&
                  fee["taxes_amount_cents"] > remaining_taxes_amount_cents.to_i.abs
                fee["taxes_amount_cents"] = fee["taxes_amount_cents"] + remaining_taxes_amount_cents.to_i
                remaining_taxes_amount_cents = 0
              end

              fee
            end
          end

          def item(fee)
            mapped_item = if fee.charge?
              billable_metric_item(fee)
            elsif fee.add_on?
              add_on_item(fee)
            elsif fee.fixed_charge?
              fixed_charge_item(fee)
            elsif fee.credit?
              credit_item
            elsif fee.commitment?
              commitment_item
            elsif fee.subscription?
              subscription_item
            end

            unless mapped_item
              raise Integrations::Aggregator::BasePayload::Failure.new(nil, code: "invalid_mapping")
            end

            {
              "external_id" => mapped_item.external_id,
              "description" => fee.subscription? ? "Subscription" : fee.charge_filter&.display_name || fee.invoice_name,
              "units" => fee.units,
              "precise_unit_amount" => fee.precise_unit_amount,
              "account_code" => mapped_item.external_account_code,
              "taxes_amount_cents" => fee.taxes_amount_cents
            }
          end

          def taxes_amount_cents(fee)
            fee.amount_cents * fee.taxes_rate
          end

          def discounts
            output = []

            if invoice.coupons_amount_cents > 0
              tax_diff_amount_cents = invoice.taxes_amount_cents - fees.sum { |f| f["taxes_amount_cents"] }

              output << {
                "external_id" => coupon_item.external_id,
                "description" => "Coupons",
                "units" => 1,
                "precise_unit_amount" => -amount(invoice.coupons_amount_cents, resource: invoice),
                "taxes_amount_cents" => -(tax_diff_amount_cents || 0).abs,
                "account_code" => coupon_item.external_account_code
              }
            end

            if credit_item && invoice.prepaid_credit_amount_cents > 0
              output << {
                "external_id" => credit_item.external_id,
                "description" => "Prepaid credit",
                "units" => 1,
                "precise_unit_amount" => -amount(invoice.prepaid_credit_amount_cents, resource: invoice),
                "taxes_amount_cents" => 0,
                "account_code" => credit_item.external_account_code
              }
            end

            if credit_item && invoice.progressive_billing_credit_amount_cents > 0
              output << {
                "external_id" => credit_item.external_id,
                "description" => "Usage already billed",
                "units" => 1,
                "precise_unit_amount" => -amount(invoice.progressive_billing_credit_amount_cents, resource: invoice),
                "taxes_amount_cents" => 0,
                "account_code" => credit_item.external_account_code
              }
            end

            if credit_note_item && invoice.credit_notes_amount_cents > 0
              output << {
                "external_id" => credit_note_item.external_id,
                "description" => "Credit note",
                "units" => 1,
                "precise_unit_amount" => -amount(invoice.credit_notes_amount_cents, resource: invoice),
                "taxes_amount_cents" => 0,
                "account_code" => credit_note_item.external_account_code
              }
            end

            output
          end

          def invoice_url
            url = ENV["LAGO_FRONT_URL"].presence || "https://app.getlago.com"

            URI.join(url, "/#{invoice.customer.organization.slug}/customer/#{invoice.customer.id}/", "invoice/#{invoice.id}/overview").to_s
          end
        end
      end
    end
  end
end
