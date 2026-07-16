# frozen_string_literal: true

module V1
  module Analytics
    class OverdueBalanceSerializer < ModelSerializer
      def serialize
        {
          month: model["month"],
          amount_cents: model["amount_cents"],
          currency: model["currency"],
          lago_invoice_ids: JSON.parse(model["lago_invoice_ids"]).flatten,
          billing_entity_id: model["billing_entity_id"]
        }
      end
    end
  end
end
