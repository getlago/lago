# frozen_string_literal: true

require "rails_helper"

RSpec.describe Webhooks::Wallets::TerminatedService do
  subject(:webhook_service) { described_class.new(object: wallet) }

  let(:wallet) { create(:wallet, :terminated, terminated_at: Time.current) }

  before { Timecop.freeze(DateTime.new(2025, 1, 31, 12, 5, 55)) }

  describe ".call" do
    it_behaves_like "creates webhook", "wallet.terminated", "wallet", {
      "balance_cents" => 0,
      "created_at" => "2025-01-31T12:05:55Z",
      "terminated_at" => "2025-01-31T12:05:55.000Z",
      "recurring_transaction_rules" => []
    }
  end
end
