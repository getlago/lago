# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resolvers::CustomerPortal::WalletResolver do
  let(:query) do
    <<~GQL
      query($walletId: ID!) {
        customerPortalWallet(id: $walletId) {
          id
          name
          priority
          currency
          status
        }
      }
    GQL
  end

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:customer) { create(:customer, organization:) }
  let(:wallet) { create(:wallet, organization:, customer:) }

  before do
    customer
  end

  it_behaves_like "requires a customer portal user"

  it "returns a single wallet" do
    result = execute_graphql(
      customer_portal_user: customer,
      query:,
      variables: {walletId: wallet.id}
    )

    wallet_response = result["data"]["customerPortalWallet"]
    expect(wallet_response).to include(
      "id" => wallet.id,
      "name" => wallet.name,
      "priority" => wallet.priority,
      "currency" => wallet.currency,
      "status" => wallet.status
    )
  end

  context "when wallet is not found" do
    it "returns an error" do
      result = execute_graphql(
        customer_portal_user: customer,
        query:,
        variables: {walletId: "foo"}
      )

      expect_graphql_error(result:, message: "Resource not found")
    end
  end
end
