# frozen_string_literal: true

require "rails_helper"

describe "Voiding wallet credits", :premium do
  let(:organization) { create(:organization, :with_static_values, webhook_url: nil) }
  let(:customer) { create(:customer, :with_static_values, organization:) }

  around do |test|
    # Set the time to have a fixed issue date in invoice
    travel_to Time.zone.local(2025, 1, 1, 0, 0, 0), &test
  end

  it "voids a wallet credit" do
    wallet = create_wallet({
      external_customer_id: customer.external_id,
      rate_amount: "1",
      name: "Wallet1",
      currency: "EUR",
      granted_credits: "100",
      invoice_requires_successful_payment: false
    }, as: :model)

    transactions = create_wallet_transaction({
      wallet_id: wallet.id,
      voided_credits: "14.28444999"
    }, as: :model)

    expect(transactions.count).to eq(1)
    transaction = transactions.first
    expect(transaction.status).to eq("settled")
    expect(transaction.transaction_status).to eq("voided")
    expect(transaction.amount).to eq(14.28)
    expect(transaction.credit_amount).to eq(14.28444)

    wallet.reload
    expect(wallet.credits_balance).to eq(85.71556)
    # FIXME
    expect(wallet.balance.to_d).to eq(85.72)
  end
end
