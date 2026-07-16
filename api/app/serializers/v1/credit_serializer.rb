# frozen_string_literal: true

module V1
  class CreditSerializer < ModelSerializer
    def serialize
      {
        lago_id: model.id,
        amount_cents: model.amount_cents,
        amount_currency: model.amount_currency,
        before_taxes: model.before_taxes,
        item: {
          lago_item_id: model.item_id,
          type: model.item_type,
          code: model.item_code,
          name: model.item_name,
          description: model.item_description
        },
        invoice: {
          lago_id: model.invoice_id,
          payment_status: model.invoice.payment_status
        }
      }
    end
  end
end
