# frozen_string_literal: true

module Integrations
  module Aggregator
    module Invoices
      module Payloads
        class Netsuite < BasePayload
          MAX_DECIMALS = 15
          NS_QUANTITY_LIMIT = 10_000_000_000

          def body
            result = {
              "type" => "invoice",
              "isDynamic" => true,
              "columns" => columns,
              "lines" => [
                {
                  "sublistId" => "item",
                  "lineItems" => fee_items + discounts
                }
              ],
              "options" => {
                "ignoreMandatoryFields" => false,
                "fullInvoicePayload" => {
                  "invoice_payload" => ::V1::InvoiceSerializer.new(
                    invoice,
                    root_name: "invoice",
                    includes: %i[customer integration_customers billing_periods subscriptions fees credits metadata applied_taxes]
                  ).serialize
                }
              }
            }

            if tax_item_complete?
              result["taxdetails"] = [
                {
                  "sublistId" => "taxdetails",
                  "lineItems" => tax_line_items + discount_taxes
                }
              ]
            end

            result
          end

          private

          def columns
            result = {
              "tranid" => invoice.number,
              "custbody_ava_disable_tax_calculation" => true,
              "custbody_lago_invoice_link" => invoice_url,
              "trandate" => issuing_date,
              "duedate" => due_date,
              "taxdetailsoverride" => true,
              "custbody_lago_id" => invoice.id,
              "entity" => integration_customer.external_customer_id,
              "lago_plan_codes" => invoice.invoice_subscriptions.map(&:subscription).map(&:plan).map(&:code).join(",")
            }

            mapped_currency = netsuite_currency_for(currency: invoice.currency)
            if mapped_currency.present?
              result["currency"] = mapped_currency.to_s
            end

            if tax_item&.tax_nexus.present?
              result["nexus"] = tax_item.tax_nexus
            end

            result["taxregoverride"] = true

            result
          end

          def tax_line_items
            fees.map { |fee| tax_line_item(fee) }
          end

          def tax_line_item(fee)
            {
              "taxdetailsreference" => fee.id,
              "taxamount" => amount(fee.taxes_amount_cents, resource: invoice),
              "taxbasis" => 1,
              "taxrate" => fee.taxes_rate,
              "taxtype" => tax_item.tax_type,
              "taxcode" => tax_item.tax_code
            }
          end

          def due_date
            invoice.payment_due_date&.strftime("%-m/%-d/%Y")
          end

          def issuing_date
            invoice.issuing_date&.strftime("%-m/%-d/%Y")
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

            from_property = fee.charge? ? "charges_from_datetime" : "from_datetime"
            to_property = fee.charge? ? "charges_to_datetime" : "to_datetime"

            quantity_value = limited_rate(fee.units)
            unit_rate_value = limited_rate(fee.precise_unit_amount)
            line_amount_value = limited_rate(amount(fee.amount_cents, resource: invoice))

            if quantity_value.respond_to?(:abs) && quantity_value.abs >= NS_QUANTITY_LIMIT
              quantity_value = 1
              unit_rate_value = line_amount_value
            end

            {
              "item" => mapped_item.external_id,
              "account" => mapped_item.external_account_code,
              "quantity" => quantity_value,
              "rate" => unit_rate_value,
              "amount" => line_amount_value,
              "taxdetailsreference" => fee.id,
              "custcol_service_period_date_from" => fee.properties[from_property]&.to_date&.strftime("%-m/%-d/%Y"),
              "custcol_service_period_date_to" => fee.properties[to_property]&.to_date&.strftime("%-m/%-d/%Y"),
              "description" => fee.item_name,
              "item_source" => fee.item_source
            }
          end

          def netsuite_currency_for(currency:)
            mapping = IntegrationCollectionMappings::NetsuiteCollectionMapping.find_by(
              integration_id: integration_customer.integration_id,
              mapping_type: :currencies
            )
            mapping&.currencies&.dig(currency)
          end

          def discounts
            output = []

            if coupon_item && invoice.coupons_amount_cents > 0
              output << {
                "item" => coupon_item.external_id,
                "account" => coupon_item.external_account_code,
                "quantity" => 1,
                "rate" => -amount(invoice.coupons_amount_cents, resource: invoice),
                "taxdetailsreference" => "coupon_item",
                "description" => invoice.credits.coupon_kind.map(&:item_name).join(","),
                "item_source" => "coupons"
              }
            end

            if credit_item && invoice.prepaid_credit_amount_cents > 0
              output << {
                "item" => credit_item.external_id,
                "account" => credit_item.external_account_code,
                "quantity" => 1,
                "rate" => -amount(invoice.prepaid_credit_amount_cents, resource: invoice),
                "taxdetailsreference" => "credit_item",
                "description" => "Prepaid credits",
                "item_source" => "prepaid_credits"
              }
            end

            if credit_item && invoice.progressive_billing_credit_amount_cents > 0
              output << {
                "item" => credit_item.external_id,
                "account" => credit_item.external_account_code,
                "quantity" => 1,
                "rate" => -amount(invoice.progressive_billing_credit_amount_cents, resource: invoice),
                "taxdetailsreference" => "credit_item_progressive_billing",
                "description" => invoice.credits.progressive_billing_invoice_kind.map(&:item_name).join(","),
                "item_source" => "progressive_billing_credits"
              }
            end

            if credit_note_item && invoice.credit_notes_amount_cents > 0
              output << {
                "item" => credit_note_item.external_id,
                "account" => credit_note_item.external_account_code,
                "quantity" => 1,
                "rate" => -amount(invoice.credit_notes_amount_cents, resource: invoice),
                "taxdetailsreference" => "credit_note_item",
                "description" => invoice.credits.credit_note_kind.map(&:item_name).join(","),
                "item_source" => "credit_note_credits"
              }
            end

            output
          end

          def discount_taxes
            output = []

            if invoice.coupons_amount_cents > 0
              tax_diff_amount_cents = invoice.taxes_amount_cents - fees.sum { |f| f["taxes_amount_cents"] }

              output << {
                "taxbasis" => 1,
                "taxamount" => amount(tax_diff_amount_cents, resource: invoice),
                "taxrate" => invoice.taxes_rate,
                "taxtype" => tax_item.tax_type,
                "taxcode" => tax_item.tax_code,
                "taxdetailsreference" => "coupon_item"
              }
            end

            if credit_item && invoice.prepaid_credit_amount_cents > 0
              output << {
                "taxbasis" => 1,
                "taxamount" => 0,
                "taxrate" => invoice.taxes_rate,
                "taxtype" => tax_item.tax_type,
                "taxcode" => tax_item.tax_code,
                "taxdetailsreference" => "credit_item"
              }
            end

            if credit_item && invoice.progressive_billing_credit_amount_cents > 0
              output << {
                "taxbasis" => 1,
                "taxamount" => 0,
                "taxrate" => invoice.taxes_rate,
                "taxtype" => tax_item.tax_type,
                "taxcode" => tax_item.tax_code,
                "taxdetailsreference" => "credit_item_progressive_billing"
              }
            end

            if credit_note_item && invoice.credit_notes_amount_cents > 0
              output << {
                "taxbasis" => 1,
                "taxamount" => 0,
                "taxrate" => invoice.taxes_rate,
                "taxtype" => tax_item.tax_type,
                "taxcode" => tax_item.tax_code,
                "taxdetailsreference" => "credit_note_item"
              }
            end

            output
          end

          def limited_rate(precise_unit_amount)
            unit_amount_str = precise_unit_amount.to_s

            return precise_unit_amount if unit_amount_str.length <= MAX_DECIMALS

            decimal_position = unit_amount_str.index(".")

            return precise_unit_amount unless decimal_position

            precise_unit_amount.round(MAX_DECIMALS - 1 - decimal_position)
          end
        end
      end
    end
  end
end
