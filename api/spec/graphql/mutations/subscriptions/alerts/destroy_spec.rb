# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::Subscriptions::Alerts::Destroy do
  let(:required_permission) { "subscriptions:update" }
  let(:membership) { create(:membership) }
  let(:customer) { create(:customer, organization: membership.organization) }
  let(:subscription) { create(:subscription, customer:) }
  let(:alert) { create(:usage_current_amount_alert, subscription_external_id: subscription.external_id, organization: membership.organization, recurring_threshold: 33, thresholds: [10, 20, 22]) }

  let(:mutation) do
    <<-GQL
    mutation ($input: DestroySubscriptionAlertInput!) {
      destroySubscriptionAlert(input: $input) {
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
  it_behaves_like "requires permission", "subscriptions:update"

  it "creates an alert" do
    result = execute_graphql(
      current_user: membership.user,
      current_organization: membership.organization,
      permissions: required_permission,
      query: mutation,
      variables: {
        input: {id: alert.id}
      }
    )

    result_data = result["data"]["destroySubscriptionAlert"]
    expect(result_data["alertType"]).to eq "current_usage_amount"
    expect(result_data["code"]).to start_with "default"
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
