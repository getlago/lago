# frozen_string_literal: true

require "rails_helper"

RSpec.describe ::V1::PaymentProviders::WalletTransactionPaymentErrorSerializer do
  subject(:serializer) { described_class.new(wallet_transaction, options) }

  let(:wallet_transaction) { create(:wallet_transaction) }
  let(:options) do
    {
      "provider_customer_id" => "customer",
      "provider_error" => {
        "error_message" => "message",
        "error_code" => "code"
      }
    }.with_indifferent_access
  end

  it "serializes the object" do
    result = JSON.parse(serializer.to_json)

    expect(result["data"]["lago_wallet_transaction_id"]).to eq(wallet_transaction.id)
    expect(result["data"]["lago_customer_id"]).to eq(wallet_transaction.wallet.customer.id)
    expect(result["data"]["external_customer_id"]).to eq(wallet_transaction.wallet.customer.external_id)
    expect(result["data"]["provider_customer_id"]).to eq(options[:provider_customer_id])
    expect(result["data"]["payment_provider"]).to eq(wallet_transaction.wallet.customer.payment_provider)
    expect(result["data"]["payment_provider_code"]).to eq(wallet_transaction.wallet.customer.payment_provider_code)
    expect(result["data"]["provider_error"]).to eq(options[:provider_error])
  end
end
