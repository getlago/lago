# frozen_string_literal: true

require "rails_helper"

describe "Wallet Transaction with name", :premium do
  let(:organization) { create(:organization, :with_static_values, webhook_url: nil) }
  let(:customer) { create(:customer, :with_static_values, organization:) }

  def within_first_day(&block)
    travel_to Time.zone.local(2025, 1, 2, 0, 0, 0) do
      yield
    end
  end

  def within_second_day(&block)
    travel_to Time.zone.local(2025, 1, 3, 0, 0, 0) do
      yield
    end
  end

  def test_invoice_on_wallet_creation(attrs: {}, snapshot_name: nil)
    wallet = within_first_day do
      create_wallet({
        external_customer_id: customer.external_id,
        rate_amount: "1",
        currency: "EUR",
        paid_credits: "100",
        **attrs
      }, as: :model)
    end

    expect(wallet.rate_amount).to eq(1)

    wallet_transactions = wallet.wallet_transactions
    expect(wallet_transactions.count).to eq(1)
    expect(wallet_transactions.first.name).to eq(attrs[:transaction_name])

    invoice = customer.invoices.credit.sole
    expect(invoice.file.download).to match_html_snapshot(name: snapshot_name)

    wallet
  end

  context "when the transaction name is provided" do
    it "renders the transaction name on the invoice" do
      wallet = test_invoice_on_wallet_creation(
        attrs: {transaction_name: "Initial top-up"},
        snapshot_name: "Initial top-up"
      )

      wt = within_second_day do
        create_wallet_transaction({
          wallet_id: wallet.id,
          paid_credits: "200",
          metadata: [{key: "transaction_id", value: "123"}],
          name: "Top-up"
        }, as: :model).first
      end

      expect(wt.status).to eq "pending"
      expect(wt.transaction_status).to eq "purchased"
      expect(wt.invoice_requires_successful_payment).to be false
      expect(wt.credit_amount).to eq(200)
      expect(wt.amount).to eq(200)
      expect(wt.name).to eq("Top-up")
      expect(wt.metadata).to eq([{"key" => "transaction_id", "value" => "123"}])

      top_up_invoice = customer.invoices.credit.order(:created_at).last
      expect(top_up_invoice.file.download).to match_html_snapshot(name: "Top-up")
    end
  end

  context "when the transaction name is not provided" do
    context "when the wallet has a name" do
      it "renders the wallet name on the invoice" do
        test_invoice_on_wallet_creation(attrs: {name: "My wallet"})
      end
    end

    context "when the wallet has no name" do
      it "renders the default name on the invoice" do
        test_invoice_on_wallet_creation
      end
    end
  end
end
