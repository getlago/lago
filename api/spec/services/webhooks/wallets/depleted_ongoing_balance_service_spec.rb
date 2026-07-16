# frozen_string_literal: true

require "rails_helper"

RSpec.describe Webhooks::Wallets::DepletedOngoingBalanceService do
  subject(:webhook_service) { described_class.new(object: wallet) }

  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:wallet) { create(:wallet, customer:) }

  describe ".call" do
    it_behaves_like "creates webhook", "wallet.depleted_ongoing_balance", "wallet"
  end
end
