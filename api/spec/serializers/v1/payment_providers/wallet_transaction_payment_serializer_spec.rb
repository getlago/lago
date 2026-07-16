# frozen_string_literal: true

require "rails_helper"

RSpec.describe V1::PaymentProviders::WalletTransactionPaymentSerializer do
  subject(:serializer) { described_class.new(wallet_transaction, options) }

  let(:wallet_transaction) { create(:wallet_transaction, :with_invoice) }
  let(:options) do
    {"payment_url" => "https://example.com"}.with_indifferent_access
  end

  it "serializes the object" do
    result = JSON.parse(serializer.to_json)

    expect(result["data"]["lago_customer_id"]).to eq(wallet_transaction.invoice.customer.id)
    expect(result["data"]["external_customer_id"]).to eq(wallet_transaction.invoice.customer.external_id)
    expect(result["data"]["payment_provider"]).to eq(wallet_transaction.invoice.customer.payment_provider)
    expect(result["data"]["lago_wallet_transaction_id"]).to eq(wallet_transaction.id)
    expect(result["data"]["payment_url"]).to eq("https://example.com")
  end
end
