# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::WalletTransactions::Create do
  subject(:result) { execute_query(query:, input:) }

  let(:required_permission) { "wallets:top_up" }
  let(:organization) { create(:organization) }
  let(:membership) { create(:membership, organization:) }
  let(:customer) { create(:customer, organization:) }
  let(:subscription) { create(:subscription, customer:) }
  let(:wallet) { create(:wallet, customer:, balance: 10.0, credits_balance: 10.0) }

  let(:query) do
    <<-GQL
    mutation ($input: CreateCustomerWalletTransactionInput!) {
      createCustomerWalletTransaction(input: $input) {
        collection {
          id
          status
          priority
          source
          name
          invoiceRequiresSuccessfulPayment
          transactionStatus
          transactionType
          creditAmount
          amount
          metadata {
            key
            value
          }
        }
      }
    }
    GQL
  end

  let(:input) do
    {
      walletId: wallet.id,
      name: "Test Transaction",
      paidCredits: "5.00",
      grantedCredits: "15.00",
      invoiceRequiresSuccessfulPayment: true,
      priority: 25,
      metadata: [
        {
          key: "fixed",
          value: "0"
        },
        {
          key: "test 2",
          value: "mew meta"
        }
      ]
    }
  end

  before do
    subscription
    wallet
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "wallets:top_up"

  it "creates a wallet transaction" do
    result_data = result["data"]["createCustomerWalletTransaction"]
    transactions = result_data["collection"].sort_by { |wt| wt["transactionStatus"] }

    expect(transactions.length).to eq(2)
    expect(transactions).to all(include(
      "metadata" => contain_exactly(
        {"key" => "fixed", "value" => "0"},
        {"key" => "test 2", "value" => "mew meta"}
      ),
      "name" => "Test Transaction",
      "priority" => 25,
      "transactionType" => "inbound",
      "source" => "manual"
    ))

    granted_transaction = transactions.first
    paid_transaction = transactions.second

    expect(granted_transaction).to include(
      "transactionStatus" => "granted",
      "status" => "settled",
      "creditAmount" => "15.0",
      "amount" => "15.0",
      "invoiceRequiresSuccessfulPayment" => false
    )

    expect(paid_transaction).to include(
      "transactionStatus" => "purchased",
      "status" => "pending",
      "creditAmount" => "5.0",
      "amount" => "5.0",
      "invoiceRequiresSuccessfulPayment" => true
    )
  end

  context "when wallet has a minimum amount" do
    before do
      wallet.update!(paid_top_up_min_amount_cents: 10_00)
    end

    it "returns an error" do
      # TODO: check error content when we return metadata
      expect_unprocessable_entity(result)
    end

    context "when the ignore_paid_top_up_limits is passed" do
      let(:input) do
        {
          walletId: wallet.id,
          paidCredits: "5.00",
          ignorePaidTopUpLimits: true
        }
      end

      it "creates the transaction" do
        expect { subject }.to change(organization.wallet_transactions, :count).by(1)

        result_data = result["data"]["createCustomerWalletTransaction"]
        expect(result_data["collection"].count).to eq 1
      end
    end
  end
end
