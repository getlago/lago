# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resolvers::CustomerPortal::WalletsResolver do
  let(:query) do
    <<~GQL
      query {
        customerPortalWallets {
          collection {
            id
            name
            priority
            currency
            paidTopUpMinAmountCents
            paidTopUpMinCredits
          }
        }
      }
    GQL
  end

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:customer) { create(:customer, organization:) }
  let(:wallet) { create(:wallet, organization:, customer:, paid_top_up_min_amount_cents: 10_00) }

  before do
    wallet

    create(:wallet, status: :terminated, customer:, organization:)
  end

  it_behaves_like "requires a customer portal user"

  it "returns a list of active wallets" do
    result = execute_graphql(
      customer_portal_user: customer,
      query:
    )

    wallets_response = result["data"]["customerPortalWallets"]
    expect(wallets_response["collection"].count).to eq(customer.wallets.active.count)

    wallet_item = wallets_response["collection"].sole
    expect(wallet_item["id"]).to eq(wallet.id)
    expect(wallet_item["name"]).to eq(wallet.name)
    expect(wallet_item["priority"]).to eq(wallet.priority)
    expect(wallet_item["currency"]).to eq(wallet.currency)
    expect(wallet_item["paidTopUpMinAmountCents"]).to eq("1000")
    expect(wallet_item["paidTopUpMinCredits"]).to eq("10")
  end

  context "without customer portal user" do
    it "returns an error" do
      result = execute_graphql(
        query:
      )

      expect_unauthorized_error(result)
    end
  end
end
