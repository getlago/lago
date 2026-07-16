# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resolvers::Subscriptions::AlertsResolver do
  let(:required_permission) { "subscriptions:view" }

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:subscription) { create(:subscription) }
  let(:alert) { create(:alert, organization:, subscription_external_id: subscription.external_id, recurring_threshold: 33, thresholds: [10, 20]) }
  let(:alert_bm) { create(:billable_metric_current_usage_amount_alert, organization:, subscription_external_id: subscription.external_id, recurring_threshold: 33, thresholds: [10, 20]) }
  let(:another_alert) { create(:alert, organization:) }

  let(:query) do
    <<~GQL
      query($subscriptionExternalId: String!) {
        subscriptionAlerts(subscriptionExternalId: $subscriptionExternalId) {
          collection { id name code deletedAt thresholds { code value recurring} }
          metadata { currentPage, totalCount }
        }
      }
    GQL
  end

  before do
    alert
    alert_bm
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "subscriptions:view"

  it "returns all alerts" do
    result = execute_graphql(
      current_user: membership.user,
      current_organization: organization,
      permissions: required_permission,
      query:,
      variables: {subscriptionExternalId: subscription.external_id}
    )

    alerts = result["data"]["subscriptionAlerts"]["collection"]

    expect(alerts.pluck("id")).to contain_exactly(alert.id, alert_bm.id)
    expect(alerts).to all(include({"name" => "General Alert", "deletedAt" => nil}))
    expect(alerts.pluck("code")).to all(start_with("default"))
    expect(alerts.pluck("thresholds")).to all(contain_exactly(
      {"code" => "warn10", "value" => "10.0", "recurring" => false},
      {"code" => "warn20", "value" => "20.0", "recurring" => false},
      {"code" => "rec", "value" => "33.0", "recurring" => true}
    ))

    metadata = result["data"]["subscriptionAlerts"]["metadata"]
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
        variables: {subscriptionExternalId: "invalid"}
      )

      expect(result["data"]["subscriptionAlerts"]["collection"]).to be_empty
    end
  end

  context "when making a list of existing alerts combination" do
    let(:query) do
      <<~GQL
        query($subscriptionExternalId: String!) {
          subscriptionAlerts(subscriptionExternalId: $subscriptionExternalId) {
            collection { alertType billableMetricId }
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
        variables: {subscriptionExternalId: subscription.external_id}
      )
      alerts = result["data"]["subscriptionAlerts"]["collection"]

      h = alerts.find { it["alertType"] == "billable_metric_current_usage_amount" }
      expect(h["billableMetricId"]).to eq alert_bm.billable_metric_id

      metadata = result["data"]["subscriptionAlerts"]["metadata"]
      expect(metadata["currentPage"]).to eq(1)
      expect(metadata["totalCount"]).to eq(2)
    end
  end
  #
  # context "when requesting relationships" do
  #   let(:query) do
  #     <<~GQL
  #       query($subscriptionExternalId: String!) {
  #         alerts(subscriptionExternalId: $subscriptionExternalId) {
  #           collection { code billableMetric { id } thresholds { value } }
  #         }
  #       }
  #     GQL
  #   end
  #
  #   it "eager loads the relationships", :bullet do
  #     create_list(:billable_metric_current_usage_amount_alert, 3, organization:, subscription_external_id: subscription.external_id, thresholds: [10])
  #
  #     Bullet.start_request
  #
  #     execute_graphql(
  #       current_user: membership.user,
  #       current_organization: organization,
  #       permissions: required_permission,
  #       query:,
  #       variables: {subscriptionExternalId: subscription.external_id}
  #     )
  #
  #     expect(Bullet.notification?).to eq false
  #   end
  # end
end
