# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::WalletTransactionFundings::Object do
  subject { described_class }

  it "has the expected fields with correct types" do
    expect(subject).to have_field(:id).of_type("ID!")
    expect(subject).to have_field(:amount_cents).of_type("BigInt!")
    expect(subject).to have_field(:created_at).of_type("ISO8601DateTime!")
    expect(subject).to have_field(:credit_amount).of_type("String!")
    expect(subject).to have_field(:wallet_transaction).of_type("WalletTransaction!")
  end

  describe "#amount_cents" do
    subject { run_graphql_field("WalletTransactionFunding.amountCents", consumption) }

    let(:organization) { create(:organization) }
    let(:customer) { create(:customer, organization:) }
    let(:wallet) { create(:wallet, customer:, traceable: true) }
    let(:inbound_transaction) do
      create(:wallet_transaction,
        wallet:,
        organization:,
        transaction_type: :inbound,
        remaining_amount_cents: 10000)
    end
    let(:outbound_transaction) do
      create(:wallet_transaction, wallet:, organization:, transaction_type: :outbound)
    end
    let(:consumption) do
      create(:wallet_transaction_consumption,
        organization:,
        inbound_wallet_transaction: inbound_transaction,
        outbound_wallet_transaction: outbound_transaction,
        consumed_amount_cents: 5000)
    end

    it "returns the consumed_amount_cents" do
      expect(subject).to eq(5000)
    end
  end

  describe "#credit_amount" do
    subject { run_graphql_field("WalletTransactionFunding.creditAmount", consumption) }

    let(:organization) { create(:organization) }
    let(:customer) { create(:customer, organization:) }
    let(:wallet) { create(:wallet, customer:, traceable: true, rate_amount: 1.5) }
    let(:inbound_transaction) do
      create(:wallet_transaction,
        wallet:,
        organization:,
        transaction_type: :inbound,
        remaining_amount_cents: 10000)
    end
    let(:outbound_transaction) do
      create(:wallet_transaction, wallet:, organization:, transaction_type: :outbound)
    end
    let(:consumption) do
      create(:wallet_transaction_consumption,
        organization:,
        inbound_wallet_transaction: inbound_transaction,
        outbound_wallet_transaction: outbound_transaction,
        consumed_amount_cents: 3000)
    end

    it "returns the credit amount by dividing consumed amount by wallet rate" do
      expect(subject).to eq("20.0")
    end
  end

  describe "#wallet_transaction" do
    subject { run_graphql_field("WalletTransactionFunding.walletTransaction", consumption) }

    let(:organization) { create(:organization) }
    let(:customer) { create(:customer, organization:) }
    let(:wallet) { create(:wallet, customer:, traceable: true) }
    let(:inbound_transaction) do
      create(:wallet_transaction,
        wallet:,
        organization:,
        transaction_type: :inbound,
        remaining_amount_cents: 10000)
    end
    let(:outbound_transaction) do
      create(:wallet_transaction, wallet:, organization:, transaction_type: :outbound)
    end
    let(:consumption) do
      create(:wallet_transaction_consumption,
        organization:,
        inbound_wallet_transaction: inbound_transaction,
        outbound_wallet_transaction: outbound_transaction,
        consumed_amount_cents: 5000)
    end

    it "returns the inbound_wallet_transaction" do
      expect(subject.id).to eq(inbound_transaction.id)
    end
  end
end
