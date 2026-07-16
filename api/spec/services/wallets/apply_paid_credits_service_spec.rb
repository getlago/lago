# frozen_string_literal: true

require "rails_helper"

RSpec.describe Wallets::ApplyPaidCreditsService do
  subject(:service) { described_class.new(wallet_transaction:) }

  describe ".call" do
    let(:wallet) { create(:wallet, balance_cents: 1000, credits_balance: 10.0) }
    let(:wallet_transaction) do
      create(:wallet_transaction, wallet:, amount: 15.0, credit_amount: 15.0, status: "pending")
    end

    it "updates wallet balance" do
      service.call

      expect(wallet.reload.balance_cents).to eq 2500
    end

    it "settles the wallet transaction" do
      result = service.call

      expect(result.wallet_transaction.status).to eq("settled")
    end
  end
end
