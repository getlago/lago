# frozen_string_literal: true

FactoryBot.define do
  factory :wallet_transaction_consumption do
    transient do
      wallet { association(:wallet) }
    end
    organization { wallet.organization }
    inbound_wallet_transaction do
      association(:wallet_transaction,
        transaction_type: "inbound",
        wallet:,
        organization:,
        remaining_amount_cents: 10000)
    end
    outbound_wallet_transaction do
      association(:wallet_transaction,
        transaction_type: "outbound",
        wallet:,
        organization:)
    end
    consumed_amount_cents { 100 }
  end
end
