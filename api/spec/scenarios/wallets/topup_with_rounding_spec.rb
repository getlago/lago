# frozen_string_literal: true

require "rails_helper"

describe "Wallet Transaction with rounding", :premium do
  let(:organization) { create(:organization, :with_static_values, webhook_url: nil) }
  let(:customer) { create(:customer, :with_static_values, organization:) }

  around do |test|
    # Set the time to have a fixed issue date in invoice
    travel_to Time.zone.local(2025, 1, 1, 0, 0, 0) do
      test.run
    end
  end

  it "rounds the amount field when handling paid_credits" do
    wallet = create_wallet({
      external_customer_id: customer.external_id,
      rate_amount: "1",
      name: "Wallet1",
      currency: "EUR",
      invoice_requires_successful_payment: false
    }, as: :model)

    expect(wallet.rate_amount).to eq(1)

    wt = create_wallet_transaction({
      wallet_id: wallet.id,
      paid_credits: "17.9699999999999988631316",
      invoice_requires_successful_payment: false,
      metadata: [{key: "transaction_id", value: "123"}]
    }, as: :model).first

    expect(wt.status).to eq "pending"
    expect(wt.transaction_status).to eq "purchased"
    expect(wt.invoice_requires_successful_payment).to be false
    expect(wt.credit_amount).to eq(17.97)
    expect(wt.amount).to eq(17.97)
    expect(wt.metadata).to eq([{"key" => "transaction_id", "value" => "123"}])

    # Customer does not have a payment_provider set yet
    invoice = customer.invoices.credit.sole
    expect(invoice.file.download).to match_html_snapshot

    expect(invoice.status).to eq "finalized"
    expect(invoice.payment_status).to eq "pending"
    expect(invoice.total_amount_cents).to eq 1797

    # mark invoice as paid
    update_invoice(invoice, {payment_status: "succeeded"})
    perform_all_enqueued_jobs

    wt.reload
    expect(wt.status).to eq "settled"
    expect(wt.settled_at).not_to be_nil

    wallet.reload
    expect(wallet.credits_balance).to eq 17.97
    expect(wallet.balance_cents).to eq 1797
  end

  it "does apply rounding handling granted_credits" do
    wallet = create_wallet({
      external_customer_id: customer.external_id,
      rate_amount: "1",
      name: "Wallet1",
      currency: "EUR",
      invoice_requires_successful_payment: false
    }, as: :model)

    expect(wallet.rate_amount).to eq(1)

    wt = create_wallet_transaction({
      wallet_id: wallet.id,
      granted_credits: "17.9699999999999988631316",
      invoice_requires_successful_payment: false
    }, as: :model).first

    expect(wt.status).to eq "settled"
    expect(wt.transaction_status).to eq "granted"
    expect(wt.invoice_requires_successful_payment).to be false
    expect(wt.credit_amount).to eq(17.97)
    expect(wt.amount).to eq(17.97)

    perform_all_enqueued_jobs

    wallet.reload
    expect(wallet.credits_balance).to eq 17.97
    expect(wallet.balance.to_d).to eq 17.97
  end
end
