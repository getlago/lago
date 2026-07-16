# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::WalletTransactions::Object do
  subject { described_class }

  it "has the expected fields with correct types" do
    expect(subject).to have_field(:wallet).of_type("Wallet")

    expect(subject).to have_field(:amount).of_type("String!")
    expect(subject).to have_field(:credit_amount).of_type("String!")
    expect(subject).to have_field(:invoice_requires_successful_payment).of_type("Boolean!")
    expect(subject).to have_field(:name).of_type("String")
    expect(subject).to have_field(:priority).of_type("Int!")
    expect(subject).to have_field(:source).of_type("WalletTransactionSourceEnum!")
    expect(subject).to have_field(:status).of_type("WalletTransactionStatusEnum!")
    expect(subject).to have_field(:transaction_status).of_type("WalletTransactionTransactionStatusEnum!")
    expect(subject).to have_field(:transaction_type).of_type("WalletTransactionTransactionTypeEnum!")
    expect(subject).to have_field(:wallet_name).of_type("String")

    expect(subject).to have_field(:created_at).of_type("ISO8601DateTime!")
    expect(subject).to have_field(:failed_at).of_type("ISO8601DateTime")
    expect(subject).to have_field(:remaining_amount_cents).of_type("BigInt")
    expect(subject).to have_field(:remaining_credit_amount).of_type("String")
    expect(subject).to have_field(:invoice).of_type("Invoice")
    expect(subject).to have_field(:voided_invoice).of_type("Invoice")
    expect(subject).to have_field(:metadata).of_type("[WalletTransactionMetadataObject!]")
    expect(subject).to have_field(:settled_at).of_type("ISO8601DateTime")
    expect(subject).to have_field(:updated_at).of_type("ISO8601DateTime!")

    expect(subject).to have_field(:selected_invoice_custom_sections).of_type("[InvoiceCustomSection!]")
    expect(subject).to have_field(:skip_invoice_custom_sections).of_type("Boolean")
  end

  describe "#remaining_credit_amount" do
    subject { run_graphql_field("WalletTransaction.remainingCreditAmount", wallet_transaction) }

    context "when remaining_amount_cents is nil" do
      let(:wallet_transaction) { create(:wallet_transaction, remaining_amount_cents: nil) }

      it "returns nil" do
        expect(subject).to be_nil
      end
    end

    context "when remaining_amount_cents is set" do
      let(:customer) { create(:customer) }
      let(:wallet) { create(:wallet, customer:, rate_amount: 1.5) }
      let(:wallet_transaction) do
        create(:wallet_transaction,
          wallet:,
          transaction_type: :inbound,
          remaining_amount_cents: 3000)
      end

      it "returns the remaining credit amount as string" do
        expect(subject).to eq("20.0")
      end
    end
  end

  describe "#voided_invoice" do
    subject { run_graphql_field("WalletTransaction.voidedInvoice", wallet_transaction) }

    let(:wallet_transaction) { create(:wallet_transaction, voided_invoice:) }
    let(:voided_invoice) { nil }

    context "when voided_invoice is nil" do
      it "returns nil" do
        expect(subject).to be_nil
      end
    end

    context "when voided_invoice is present" do
      let(:voided_invoice) { create(:invoice, :voided) }

      it "returns the invoice" do
        expect(subject).to eq(voided_invoice)
      end
    end
  end

  describe "#wallet_name" do
    subject { run_graphql_field("WalletTransaction.walletName", wallet_transaction) }

    let(:wallet_transaction) { create(:wallet_transaction) }

    context "when wallet has a name" do
      it "returns the wallet name" do
        expect(subject).to be_present
        expect(subject).to eq(wallet_transaction.wallet.name)
      end
    end

    context "when wallet has no name" do
      let(:wallet_transaction) { create(:wallet_transaction, wallet: create(:wallet, name: nil)) }

      it "returns nil" do
        expect(subject).to be_nil
      end
    end
  end
end
