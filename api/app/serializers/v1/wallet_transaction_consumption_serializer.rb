# frozen_string_literal: true

module V1
  class WalletTransactionConsumptionSerializer < ModelSerializer
    def serialize
      payload = {
        lago_id: model.id,
        amount_cents: model.consumed_amount_cents,
        credit_amount: model.credit_amount,
        created_at: model.created_at.iso8601
      }

      payload.merge!(wallet_transaction(:inbound)) if include?(:inbound_wallet_transaction)
      payload.merge!(wallet_transaction(:outbound)) if include?(:outbound_wallet_transaction)

      payload
    end

    private

    def wallet_transaction(direction)
      transaction = (direction == :inbound) ? model.inbound_wallet_transaction : model.outbound_wallet_transaction
      {
        wallet_transaction: ::V1::WalletTransactionSerializer.new(transaction).serialize
      }
    end
  end
end
