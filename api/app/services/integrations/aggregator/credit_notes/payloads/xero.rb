# frozen_string_literal: true

module Integrations
  module Aggregator
    module CreditNotes
      module Payloads
        class Xero < BasePayload
          private

          def item(credit_note_item)
            item = super
            item["item_code"] = item.delete("external_id")
            item
          end

          def coupons
            coupons = super
            coupons.each do |coupon|
              coupon["item_code"] = coupon.delete("external_id")
            end
          end
        end
      end
    end
  end
end
