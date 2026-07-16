# frozen_string_literal: true

module Integrations
  module Aggregator
    module CreditNotes
      module Payloads
        class Netsuite < BasePayload
          def body
            result = {
              "type" => "creditmemo",
              "isDynamic" => true,
              "columns" => columns,
              "lines" => [
                {
                  "sublistId" => "item",
                  "lineItems" => credit_note_items + coupons
                }
              ],
              "options" => {
                "ignoreMandatoryFields" => false,
                "fullCreditNotePayload" => {
                  "credit_note_payload" => ::V1::CreditNoteSerializer.new(
                    credit_note,
                    root_name: "credit_note",
                    includes: [:items, :applied_taxes, :error_details, customer: [:integration_customers]]
                  ).serialize
                }
              }
            }

            if tax_item_complete?
              result["taxdetails"] = [
                {
                  "sublistId" => "taxdetails",
                  "lineItems" => tax_line_items_with_adjusted_taxes + coupon_taxes
                }
              ]
            end

            result
          end

          private

          def credit_note_items
            items.map { |credit_note_item| item(credit_note_item) }
          end

          def tax_line_items
            items.map { |credit_note_item| tax_line_item(credit_note_item) }
          end

          def items
            @items ||= credit_note.items.order(created_at: :asc)
          end

          def columns
            result = {
              "tranid" => credit_note.number,
              "entity" => integration_customer.external_customer_id,
              "taxregoverride" => true,
              "taxdetailsoverride" => true,
              "otherrefnum" => credit_note.number,
              "custbody_ava_disable_tax_calculation" => true,
              "custbody_lago_id" => credit_note.id,
              "tranId" => credit_note.id
            }

            if tax_item&.tax_nexus.present?
              result["nexus"] = tax_item.tax_nexus
            end

            result
          end

          def item(credit_note_item)
            fee = credit_note_item.fee

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
              "item" => mapped_item.external_id,
              "account" => mapped_item.external_account_code,
              "quantity" => 1,
              "rate" => amount(credit_note_item.amount_cents, resource: credit_note_item.credit_note),
              "taxdetailsreference" => credit_note_item.id,
              "description" => credit_note_item.fee.item_name
            }
          end

          def tax_line_item(credit_note_item)
            {
              "taxdetailsreference" => credit_note_item.id,
              "taxamount" => amount(taxes_amount(credit_note_item), resource: credit_note_item.credit_note),
              "taxbasis" => 1,
              "taxrate" => credit_note_item.fee.taxes_rate,
              "taxtype" => tax_item.tax_type,
              "taxcode" => tax_item.tax_code
            }
          end

          def tax_line_items_with_adjusted_taxes
            taxes_amount_cents_sum = tax_line_items.sum { |f| f["taxamount"].to_d }

            return tax_line_items if taxes_amount_cents_sum == credit_note.taxes_amount_cents

            adjusted_first_tax = false

            tax_line_items.map do |credit_note_item|
              if credit_note_item["taxamount"] > 0 && !adjusted_first_tax
                amount = amount(credit_note.taxes_amount_cents, resource: credit_note)
                credit_note_item["taxamount"] += amount - taxes_amount_cents_sum
                adjusted_first_tax = true
              end

              credit_note_item
            end
          end

          def taxes_amount(credit_note_item)
            subunit_to_unit = credit_note_item.amount.currency.subunit_to_unit.to_d
            amount = credit_note_item.amount_cents.fdiv(subunit_to_unit) * credit_note_item.credit_note.taxes_rate
            amount.round(2)
          end

          def coupons
            output = []

            if credit_note.coupons_adjustment_amount_cents > 0
              output << {
                "item" => coupon_item&.external_id,
                "account" => coupon_item&.external_account_code,
                "quantity" => 1,
                "rate" => -amount(credit_note.coupons_adjustment_amount_cents, resource: credit_note),
                "taxdetailsreference" => "coupon_item",
                "description" => credit_note.invoice.credits.coupon_kind.map(&:item_name).join(",")
              }
            end

            output
          end

          def coupon_taxes
            output = []

            if credit_note.coupons_adjustment_amount_cents > 0
              output << {
                "taxbasis" => 1,
                "taxamount" => 0,
                "taxrate" => credit_note.taxes_rate,
                "taxtype" => tax_item.tax_type,
                "taxcode" => tax_item.tax_code,
                "taxdetailsreference" => "coupon_item"
              }
            end

            output
          end
        end
      end
    end
  end
end
