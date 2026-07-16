# frozen_string_literal: true

require "rails_helper"

RSpec.describe ::V1::WalletTransactionConsumptionSerializer do
  subject(:serializer) do
    described_class.new(consumption, root_name: "wallet_transaction_consumption", includes:)
  end

  let(:consumption) { create(:wallet_transaction_consumption) }
  let(:includes) { [] }

  context "when includes is empty" do
    it "serializes the object" do
      result = JSON.parse(serializer.to_json)

      expect(result["wallet_transaction_consumption"]).to eq(
        "lago_id" => consumption.id,
        "amount_cents" => consumption.consumed_amount_cents,
        "credit_amount" => consumption.credit_amount,
        "created_at" => consumption.created_at.iso8601
      )
    end
  end

  context "when includes inbound_wallet_transaction is set" do
    let(:includes) { %i[inbound_wallet_transaction] }

    it "includes the inbound wallet transaction as wallet_transaction" do
      result = JSON.parse(serializer.to_json)

      expect(result["wallet_transaction_consumption"]["wallet_transaction"]).to include(
        "lago_id" => consumption.inbound_wallet_transaction.id,
        "transaction_type" => "inbound"
      )
    end
  end

  context "when includes outbound_wallet_transaction is set" do
    let(:includes) { %i[outbound_wallet_transaction] }

    it "includes the outbound wallet transaction as wallet_transaction" do
      result = JSON.parse(serializer.to_json)

      expect(result["wallet_transaction_consumption"]["wallet_transaction"]).to include(
        "lago_id" => consumption.outbound_wallet_transaction.id,
        "transaction_type" => "outbound"
      )
    end
  end
end
