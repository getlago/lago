# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::Wallets::Alerts::Update do
  let(:required_permission) { "wallets:update" }
  let(:membership) { create(:membership) }
  let(:customer) { create(:customer, organization: membership.organization) }
  let(:wallet) { create(:wallet, customer:, organization: membership.organization) }
  let(:alert) { create(:wallet_balance_amount_alert, wallet:, organization: membership.organization, recurring_threshold: 10, thresholds: [75, 50, 25]) }

  let(:mutation) do
    <<-GQL
    mutation ($input: UpdateCustomerWalletAlertInput!) {
      updateCustomerWalletAlert(input: $input) {
        id
        alertType
        code
        thresholds { code value recurring }
      }
    }
    GQL
  end

  before do
    wallet
    alert
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "wallets:update"

  it "updates an alert" do
    result = execute_graphql(
      current_user: membership.user,
      current_organization: membership.organization,
      permissions: required_permission,
      query: mutation,
      variables: {
        input: {
          id: alert.id,
          code: "new code",
          thresholds: [
            {code: "warn", value: "10"},
            {code: "alert", value: "50", recurring: true}
          ]
        }
      }
    )

    result_data = result["data"]["updateCustomerWalletAlert"]
    expect(result_data["id"]).to eq alert.id
    expect(result_data["alertType"]).to eq "wallet_balance_amount"
    expect(result_data["code"]).to eq "new code"
    expect(result_data["billableMetric"]).to be_nil
    expect(result_data["thresholds"]).to contain_exactly(
      {"code" => "warn", "value" => "10.0", "recurring" => false},
      {"code" => "alert", "value" => "50.0", "recurring" => true}
    )
  end

  context "when alert is not found" do
    it "returns an error" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: membership.organization,
        permissions: required_permission,
        query: mutation,
        variables: {
          input: {
            id: SecureRandom.uuid,
            code: "new code"
          }
        }
      )

      response = result["errors"].first["extensions"]

      expect(response["status"]).to eq(404)
      expect(response["details"]["alert"]).to include("not_found")
    end
  end
end
