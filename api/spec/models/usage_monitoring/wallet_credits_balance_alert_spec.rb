# frozen_string_literal: true

require "rails_helper"

RSpec.describe UsageMonitoring::WalletCreditsBalanceAlert do
  describe "#find_value" do
    let(:alert) { create(:wallet_credits_balance_alert) }
    let(:wallet) { create(:wallet, credits_balance: 25.5) }

    it "returns the wallet credits_balance" do
      expect(alert.find_value(wallet)).to eq(25.5)
    end
  end
end
