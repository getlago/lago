# frozen_string_literal: true

require "rails_helper"

RSpec.describe Webhooks::PaymentProviders::WalletTransactionPaymentFailureService do
  subject(:webhook_service) { described_class.new(object: wallet_transaction, options: webhook_options) }

  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:wallet) { create(:wallet, customer:, organization:) }
  let(:wallet_transaction) { create(:wallet_transaction, wallet:) }
  let(:webhook_options) { {provider_error: {message: "message", error_code: "code"}} }

  before do
    wallet_transaction
  end

  describe ".call" do
    it_behaves_like "creates webhook", "wallet_transaction.payment_failure", "payment_provider_wallet_transaction_payment_error"
  end
end
