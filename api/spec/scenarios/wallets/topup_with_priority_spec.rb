# frozen_string_literal: true

require "rails_helper"

describe "Wallet Transaction with priority" do
  let(:organization) { create(:organization, webhook_url: nil) }
  let(:customer) { create(:customer, organization:) }

  context "when creating a wallet with transaction_priority" do
    it "sets the priority on the initial wallet transactions" do
      wallet = create_wallet({
        external_customer_id: customer.external_id,
        rate_amount: "1",
        currency: "EUR",
        paid_credits: "100",
        granted_credits: "50",
        transaction_priority: 5
      }, as: :model)

      expect(wallet.wallet_transactions.count).to eq(2)
      expect(wallet.wallet_transactions.pluck(:priority)).to eq([5, 5])
    end
  end

  context "when creating a wallet without transaction_priority" do
    it "uses the default priority on the initial wallet transactions" do
      wallet = create_wallet({
        external_customer_id: customer.external_id,
        rate_amount: "1",
        currency: "EUR",
        paid_credits: "100",
        granted_credits: "50"
      }, as: :model)

      expect(wallet.wallet_transactions.count).to eq(2)
      expect(wallet.wallet_transactions.pluck(:priority)).to eq([50, 50])
    end
  end

  context "when creating a wallet transaction with priority" do
    it "sets the priority on the wallet transaction" do
      wallet = create_wallet({
        external_customer_id: customer.external_id,
        rate_amount: "1",
        currency: "EUR"
      }, as: :model)

      wallet_transactions = create_wallet_transaction({
        wallet_id: wallet.id,
        paid_credits: "100",
        granted_credits: "50",
        priority: 10
      }, as: :model)

      expect(wallet_transactions.count).to eq(2)
      expect(wallet_transactions.pluck(:priority)).to eq([10, 10])
    end
  end
end
