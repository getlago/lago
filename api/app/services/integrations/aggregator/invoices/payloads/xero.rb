# frozen_string_literal: true

module Integrations
  module Aggregator
    module Invoices
      module Payloads
        class Xero < BasePayload
          def initialize(integration_customer:, invoice:)
            super
          end

          def body
            super.map do |invoice_payload|
              invoice_payload.merge("reference" => invoice.purchase_order_number)
            end
          end

          def item(fee)
            base_item = super
            base_item["item_code"] = base_item.delete("external_id")
            base_item["description"] = "#{base_item["description"]}#{fee.grouped_by_display}"

            if fee.precise_unit_amount.round(2) != fee.precise_unit_amount
              base_item["units"] = 1
              base_item["precise_unit_amount"] = amount(fee.amount_cents, resource: invoice)
            end

            base_item
          end

          def discounts
            discounts = super

            discounts.each do |discount|
              discount["item_code"] = discount.delete("external_id")
            end
          end

          private

          # Xero accepts zero-amount line items, so we bypass the
          # zero-amount fee filter defined in BasePayload (see #2656).
          def fees
            @fees ||= invoice.fees.order(created_at: :asc)
          end
        end
      end
    end
  end
end
