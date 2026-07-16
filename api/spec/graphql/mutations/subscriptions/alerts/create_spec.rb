# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::Subscriptions::Alerts::Create do
  subject(:result) do
    execute_graphql(
      current_user: membership.user,
      current_organization: membership.organization,
      permissions: required_permission,
      query: mutation,
      variables: {
        input:
      }
    )
  end

  let(:required_permission) { "subscriptions:update" }
  let(:mutation) do
    <<-GQL
    mutation ($input: CreateSubscriptionAlertInput!) {
      createSubscriptionAlert(input: $input) {
        subscriptionExternalId
        alertType
        code
        thresholds {
          code
          value
          recurring
        }
        billableMetric { id code }
      }
    }
    GQL
  end
  let(:membership) { create(:membership) }
  let(:customer) { create(:customer, organization: membership.organization) }
  let(:subscription) { create(:subscription, customer:) }

  let(:input) do
    {
      subscriptionId: subscription.id,
      code: "global",
      alertType: "current_usage_amount",
      thresholds: [
        {code: "warn", value: "10"},
        {code: "alert", value: "50"},
        {value: "20", recurring: true}
      ]
    }
  end

  before do
    subscription
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "subscriptions:update"

  it "creates an alert" do
    result_data = result["data"]["createSubscriptionAlert"]
    expect(result_data["subscriptionExternalId"]).to eq subscription.external_id
    expect(result_data["walletId"]).to be_nil
    expect(result_data["alertType"]).to eq "current_usage_amount"
    expect(result_data["code"]).to eq "global"
    expect(result_data["thresholds"]).to contain_exactly(
      {"code" => "warn", "value" => "10.0", "recurring" => false}, # Notice .0 since it's a BigDecimal
      {"code" => "alert", "value" => "50.0", "recurring" => false},
      {"code" => nil, "value" => "20.0", "recurring" => true}
    )
  end

  context "with billable_metric_id" do
    let(:billable_metric) { create(:billable_metric, organization: membership.organization) }
    let(:input) do
      {
        subscriptionId: subscription.id,
        code: "bm",
        alertType: "billable_metric_current_usage_amount",
        thresholds: [{code: "warn", value: "10"}],
        billableMetricId: billable_metric.id
      }
    end

    it "creates an alert" do
      result_data = result["data"]["createSubscriptionAlert"]
      expect(result_data["subscriptionExternalId"]).to eq subscription.external_id
      expect(result_data["alertType"]).to eq "billable_metric_current_usage_amount"
      expect(result_data["code"]).to eq "bm"
      expect(result_data["thresholds"]).to contain_exactly(
        {"code" => "warn", "value" => "10.0", "recurring" => false}
      )
      expect(result_data["billableMetric"]["id"]).to eq billable_metric.id
      expect(result_data["billableMetric"]["code"]).to eq billable_metric.code
    end
  end

  context "when billable_metric is not found" do
    let(:input) do
      {
        subscriptionId: subscription.id,
        code: "bm",
        alertType: "billable_metric_current_usage_amount",
        thresholds: [{code: "warn", value: "10"}],
        billableMetricId: SecureRandom.uuid
      }
    end

    it "returns an error" do
      response = result["errors"].first["extensions"]

      expect(response["status"]).to eq(404)
      expect(response["details"]["billableMetric"]).to include("not_found")
    end
  end

  context "when billable_metric_id are missing" do
    let(:input) do
      {
        subscriptionId: subscription.id,
        code: "bm",
        alertType: "billable_metric_current_usage_amount",
        thresholds: [{code: "warn", value: "10"}]
      }
    end

    it "returns an error" do
      response = result["errors"].first["extensions"]

      expect(response["status"]).to eq(422)
      expect(response["details"]["billableMetric"]).to include("value_is_mandatory")
    end
  end
end
