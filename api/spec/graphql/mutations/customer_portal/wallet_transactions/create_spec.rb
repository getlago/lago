# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::CustomerPortal::WalletTransactions::Create do
  let(:wallet) { create(:wallet, balance: 10.0, credits_balance: 10.0) }

  let(:mutation) do
    <<-GQL
      mutation($input: CreateCustomerPortalWalletTransactionInput!) {
        createCustomerPortalWalletTransaction(input: $input) {
          collection { id, status, amount }
        }
      }
    GQL
  end

  before do
    wallet
  end

  it_behaves_like "requires a customer portal user"

  it "creates a wallet transaction" do
    result = execute_graphql(
      customer_portal_user: wallet.customer,
      query: mutation,
      variables: {
        input: {
          walletId: wallet.id,
          paidCredits: "5.00"
        }
      }
    )

    result_data = result["data"]["createCustomerPortalWalletTransaction"]

    expect(result_data["collection"].count).to eq 1
    expect(result_data["collection"].first["status"]).to eq "pending"
    expect(result_data["collection"].first["amount"]).to eq "5.0"
  end

  context "when wallet has a minimum amount" do
    it "returns an error" do
      wallet.update!(paid_top_up_min_amount_cents: 10_00)

      result = execute_graphql(
        customer_portal_user: wallet.customer,
        query: mutation,
        variables: {
          input: {
            walletId: wallet.id,
            paidCredits: "5.123459999"
          }
        }
      )

      # TODO: improve when we have metadata on errors
      expect_unprocessable_entity(result)
    end
  end

  context "when customer tries to top up another customer's wallet" do
    let(:other_customer) { create(:customer, organization: wallet.customer.organization) }
    let(:other_wallet) { create(:wallet, customer: other_customer, balance: 10.0, credits_balance: 10.0) }

    it "returns an error" do
      result = execute_graphql(
        customer_portal_user: wallet.customer,
        query: mutation,
        variables: {
          input: {
            walletId: other_wallet.id,
            paidCredits: "5.00"
          }
        }
      )

      expect_unprocessable_entity(result)
    end
  end

  context "without customer portal user" do
    it "returns an error" do
      result = execute_graphql(
        query: mutation,
        variables: {
          input: {
            walletId: wallet.id,
            paidCredits: "5.00"
          }
        }
      )

      expect_unauthorized_error(result)
    end
  end
end
