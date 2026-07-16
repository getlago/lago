# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resolvers::Subscriptions::AlertResolver do
  let(:required_permission) { "subscriptions:view" }
  let(:query) do
    <<~GQL
      query($alertId: ID!) {
        subscriptionAlert(id: $alertId) {
          id code name thresholds {code value recurring}
        }
      }
    GQL
  end

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:alert) { create(:alert, organization:, recurring_threshold: 33, thresholds: [10, 20]) }

  before do
    alert
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "subscriptions:view"

  it "returns a single alert" do
    result = execute_graphql(
      current_user: membership.user,
      current_organization: organization,
      permissions: required_permission,
      query:,
      variables: {alertId: alert.id}
    )

    alert_response = result["data"]["subscriptionAlert"]

    expect(alert_response["id"]).to eq(alert.id)
    expect(alert_response["code"]).to start_with("default")
    expect(alert_response["name"]).to eq("General Alert")
    expect(alert_response["thresholds"].map(&:symbolize_keys)).to contain_exactly(
      {code: "warn10", value: "10.0", recurring: false},
      {code: "warn20", value: "20.0", recurring: false},
      {code: "rec", value: "33.0", recurring: true}
    )
  end

  context "when alert is not found" do
    it "returns an error" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:,
        variables: {alertId: "invalid"}
      )

      expect_graphql_error(result:, message: "Resource not found")
    end
  end
end
