# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::Wallets::Terminate do
  let(:required_permission) { "wallets:terminate" }
  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:customer) { create(:customer, organization:) }
  let(:subscription) { create(:subscription, customer:) }
  let(:wallet) { create(:wallet, customer:) }

  let(:mutation) do
    <<-GQL
      mutation($input: TerminateCustomerWalletInput!) {
        terminateCustomerWallet(input: $input) {
          id name status terminatedAt
        }
      }
    GQL
  end

  before { subscription }

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "wallets:terminate"

  it "terminates a wallet" do
    result = execute_graphql(
      current_user: membership.user,
      current_organization: organization,
      permissions: required_permission,
      query: mutation,
      variables: {
        input: {id: wallet.id}
      }
    )

    data = result["data"]["terminateCustomerWallet"]

    expect(data["id"]).to eq(wallet.id)
    expect(data["name"]).to eq(wallet.name)
    expect(data["status"]).to eq("terminated")
    expect(data["terminatedAt"]).to be_present

    expect(SendWebhookJob).to have_been_enqueued.with("wallet.terminated", Wallet)
  end
end
