# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::Subscriptions::Alerts::Update do
  let(:required_permission) { "subscriptions:update" }
  let(:membership) { create(:membership) }
  let(:customer) { create(:customer, organization: membership.organization) }
  let(:subscription) { create(:subscription, customer:, organization: membership.organization) }
  let(:alert) { create(:usage_current_amount_alert, subscription_external_id: subscription.external_id, organization: membership.organization, recurring_threshold: 33, thresholds: [10, 20, 22]) }

  let(:mutation) do
    <<-GQL
    mutation ($input: UpdateSubscriptionAlertInput!) {
      updateSubscriptionAlert(input: $input) {
        id
        alertType
        code
        thresholds { code value recurring }
        billableMetric { id code }
      }
    }
    GQL
  end

  before do
    subscription
    alert
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "subscriptions:update"

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

    result_data = result["data"]["updateSubscriptionAlert"]
    expect(result_data["id"]).to eq alert.id
    expect(result_data["alertType"]).to eq "current_usage_amount"
    expect(result_data["code"]).to eq "new code"
    expect(result_data["billableMetric"]).to be_nil
    expect(result_data["thresholds"]).to contain_exactly(
      {"code" => "warn", "value" => "10.0", "recurring" => false},
      {"code" => "alert", "value" => "50.0", "recurring" => true}
    )
  end

  context "with new billable_metric" do
    let(:alert) { create(:billable_metric_current_usage_amount_alert, subscription_external_id: subscription.external_id, organization: membership.organization, recurring_threshold: 33, thresholds: [10, 12]) }

    it "updates the alert" do
      new_billable_metric = create(:billable_metric, code: "new_bm", organization: membership.organization)

      result = execute_graphql(
        current_user: membership.user,
        current_organization: membership.organization,
        permissions: required_permission,
        query: mutation,
        variables: {
          input: {
            id: alert.id,
            code: "new code",
            billableMetricId: new_billable_metric.id
          }
        }
      )

      result_data = result["data"]["updateSubscriptionAlert"]
      expect(result_data["id"]).to eq alert.id
      expect(result_data["alertType"]).to eq "billable_metric_current_usage_amount"
      expect(result_data["code"]).to eq "new code"
      expect(result_data["thresholds"]).to contain_exactly(
        {"code" => "warn10", "value" => "10.0", "recurring" => false},
        {"code" => "warn12", "value" => "12.0", "recurring" => false},
        {"code" => "rec", "value" => "33.0", "recurring" => true}
      )
      expect(result_data["billableMetric"]["id"]).to eq new_billable_metric.id
      expect(result_data["billableMetric"]["code"]).to eq "new_bm"
    end
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
