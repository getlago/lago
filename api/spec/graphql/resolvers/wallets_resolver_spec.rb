# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resolvers::WalletsResolver do
  let(:query) do
    <<~GQL
      query($customerId: ID!) {
        wallets(customerId: $customerId, limit: 5, status: active) {
          collection { id }
          metadata { 
            currentPage,
            totalCount,
            customerActiveWalletsCount
          }
        }
      }
    GQL
  end

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:customer) { create(:customer, organization:) }
  let(:subscription) { create(:subscription, customer:, organization:) }
  let(:wallet) { create(:wallet, organization:, customer:) }

  before do
    subscription
    wallet

    create(:wallet, status: :terminated, customer:)
  end

  it "returns a list of wallets" do
    result = execute_graphql(
      current_user: membership.user,
      current_organization: organization,
      query:,
      variables: {
        customerId: customer.id
      }
    )

    wallets_response = result["data"]["wallets"]

    expect(wallets_response["collection"].count).to eq(customer.wallets.active.count)
    expect(wallets_response["collection"].first["id"]).to eq(wallet.id)

    expect(wallets_response["metadata"]["customerActiveWalletsCount"]).to eq(1)
    expect(wallets_response["metadata"]["currentPage"]).to eq(1)
    expect(wallets_response["metadata"]["totalCount"]).to eq(1)
  end

  context "without current organization" do
    it "returns an error" do
      result = execute_graphql(
        current_user: membership.user,
        query:,
        variables: {
          customerId: customer.id
        }
      )

      expect_graphql_error(
        result:,
        message: "Missing organization id"
      )
    end
  end

  context "when not member of the organization" do
    it "returns an error" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: create(:organization),
        query:,
        variables: {
          customerId: customer.id
        }
      )

      expect_graphql_error(
        result:,
        message: "Not in organization"
      )
    end
  end

  context "when customer does not exists" do
    it "returns an error" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        query:,
        variables: {
          customerId: "123456"
        }
      )

      expect_graphql_error(
        result:,
        message: "Resource not found"
      )
    end
  end
end
