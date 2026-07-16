# frozen_string_literal: true

require "rails_helper"

RSpec.describe UsageMonitoring::WalletBalanceAmountAlert do
  describe "#find_value" do
    let(:alert) { create(:wallet_balance_amount_alert) }
    let(:wallet) { create(:wallet, balance_cents: 1500) }

    it "returns the wallet balance_cents" do
      expect(alert.find_value(wallet)).to eq(1500)
    end
  end
end
