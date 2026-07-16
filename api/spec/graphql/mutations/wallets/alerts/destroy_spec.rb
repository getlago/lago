# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::Wallets::Alerts::Destroy do
  let(:required_permission) { "wallets:update" }
  let(:membership) { create(:membership) }
  let(:customer) { create(:customer, organization: membership.organization) }
  let(:wallet) { create(:wallet, customer:) }
  let(:alert) { create(:wallet_balance_amount_alert, wallet:, organization: membership.organization, recurring_threshold: 10, thresholds: [75, 50, 25]) }

  let(:mutation) do
    <<-GQL
    mutation ($input: DestroyCustomerWalletAlertInput!) {
      destroyCustomerWalletAlert(input: $input) {
        id
        alertType
        code
        deletedAt
        thresholds {
          code
          value
        }
      }
    }
    GQL
  end

  before do
    alert
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "wallets:update"

  it "destroys an alert" do
    result = execute_graphql(
      current_user: membership.user,
      current_organization: membership.organization,
      permissions: required_permission,
      query: mutation,
      variables: {
        input: {id: alert.id}
      }
    )

    result_data = result["data"]["destroyCustomerWalletAlert"]
    expect(result_data["alertType"]).to eq "wallet_balance_amount"
    expect(result_data["code"]).to start_with "default1"
    expect(result_data["thresholds"]).to be_empty
    expect(result_data["deletedAt"]).to start_with Time.current.year.to_s
  end

  context "when alert is not found" do
    it "returns an error" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: membership.organization,
        permissions: required_permission,
        query: mutation,
        variables: {
          input: {id: SecureRandom.uuid}
        }
      )

      response = result["errors"].first["extensions"]

      expect(response["status"]).to eq(404)
      expect(response["details"]["alert"]).to include("not_found")
    end
  end
end
