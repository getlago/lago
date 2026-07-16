# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resolvers::Wallets::AlertsResolver do
  let(:required_permission) { "wallets:update" }

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:wallet) { create(:wallet, organization:) }
  let(:balance_alert) { create(:wallet_balance_amount_alert, organization:, wallet:, recurring_threshold: 10, thresholds: [75, 50, 25]) }
  let(:credits_alert) { create(:wallet_credits_balance_alert, organization:, wallet:, recurring_threshold: 10, thresholds: [75, 50, 25]) }
  let(:another_alert) { create(:alert, organization:) }

  let(:query) do
    <<~GQL
      query($walletId: String!) {
        walletAlerts(walletId: $walletId) {
          collection { id name code deletedAt thresholds { code value recurring} }
          metadata { currentPage, totalCount }
        }
      }
    GQL
  end

  before do
    balance_alert
    credits_alert
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "wallets:update"

  it "returns all alerts" do
    result = execute_graphql(
      current_user: membership.user,
      current_organization: organization,
      permissions: required_permission,
      query:,
      variables: {walletId: wallet.id}
    )

    alerts = result["data"]["walletAlerts"]["collection"]

    expect(alerts.pluck("id")).to contain_exactly(balance_alert.id, credits_alert.id)
    expect(alerts).to all(include({"name" => "General Alert", "deletedAt" => nil}))
    expect(alerts.pluck("code")).to all(start_with("default"))
    expect(alerts.pluck("thresholds")).to all(contain_exactly(
      {"code" => "warn75", "value" => "75.0", "recurring" => false},
      {"code" => "warn50", "value" => "50.0", "recurring" => false},
      {"code" => "warn25", "value" => "25.0", "recurring" => false},
      {"code" => "rec", "value" => "10.0", "recurring" => true}
    ))

    metadata = result["data"]["walletAlerts"]["metadata"]
    expect(metadata["currentPage"]).to eq(1)
    expect(metadata["totalCount"]).to eq(2)
  end

  context "when no alert is not found" do
    it "returns an empty list" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:,
        variables: {walletId: "invalid"}
      )

      expect(result["data"]["walletAlerts"]["collection"]).to be_empty
    end
  end

  context "when making a list of existing alerts combination" do
    let(:query) do
      <<~GQL
        query($walletId: String!) {
          walletAlerts(walletId: $walletId) {
            collection { alertType code }
            metadata { currentPage, totalCount }
          }
        }
      GQL
    end

    it "returns all alerts" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:,
        variables: {walletId: wallet.id}
      )
      alerts = result["data"]["walletAlerts"]["collection"]

      expect(alerts).to match_array([
        include("alertType" => "wallet_balance_amount"),
        include("alertType" => "wallet_credits_balance")
      ])

      metadata = result["data"]["walletAlerts"]["metadata"]
      expect(metadata["currentPage"]).to eq(1)
      expect(metadata["totalCount"]).to eq(2)
    end
  end
end
