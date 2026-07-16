# frozen_string_literal: true

require "rails_helper"

RSpec.describe UsageMonitoring::WalletOngoingBalanceAmountAlert do
  describe "#find_value" do
    let(:alert) { create(:wallet_ongoing_balance_amount_alert) }
    let(:wallet) { create(:wallet, ongoing_balance_cents: 1500) }

    it "returns the wallet ongoing_balance_cents" do
      expect(alert.find_value(wallet)).to eq(1500)
    end
  end
end
