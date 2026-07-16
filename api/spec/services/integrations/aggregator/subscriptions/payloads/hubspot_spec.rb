# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integrations::Aggregator::Subscriptions::Payloads::Hubspot do
  let(:payload) { described_class.new(integration_customer:, subscription:) }
  let(:integration_customer) { FactoryBot.create(:hubspot_customer, integration:, customer:) }
  let(:integration) { create(:hubspot_integration, organization:) }
  let(:customer) { create(:customer, organization:) }
  let(:file_url) { Faker::Internet.url }
  let(:subscription) { create(:subscription, customer:, plan:) }
  let(:plan) { create(:plan, organization:) }
  let(:organization) { create(:organization) }

  let(:integration_subscription) do
    create(:integration_resource, integration:, resource_type: "subscription", syncable: subscription)
  end

  let(:subscription_url) do
    url = ENV["LAGO_FRONT_URL"].presence || "https://app.getlago.com"
    URI.join(url, "/#{customer.organization.slug}/customer/#{customer.id}/subscription/#{subscription.id}/overview").to_s
  end

  before do
    integration_subscription
  end

  describe "#create_body" do
    subject(:body_call) { payload.create_body }

    let(:create_body) do
      {
        "objectType" => integration.subscriptions_object_type_id,
        "input" => {
          "associations" => [],
          "properties" => {
            "lago_subscription_id" => subscription.id,
            "lago_external_subscription_id" => subscription.external_id,
            "lago_billing_time" => subscription.billing_time,
            "lago_subscription_name" => subscription.name,
            "lago_subscription_plan_code" => subscription.plan.code,
            "lago_subscription_status" => subscription.status,
            "lago_subscription_created_at" => subscription.created_at.strftime("%Y-%m-%d"),
            "lago_subscription_started_at" => subscription.started_at&.strftime("%Y-%m-%d"),
            "lago_subscription_ending_at" => subscription.ending_at&.strftime("%Y-%m-%d"),
            "lago_subscription_at" => subscription.subscription_at&.strftime("%Y-%m-%d"),
            "lago_subscription_terminated_at" => subscription.terminated_at&.strftime("%Y-%m-%d"),
            "lago_subscription_trial_ended_at" => subscription.trial_ended_at&.strftime("%Y-%m-%d"),
            "lago_subscription_link" => subscription_url
          }
        }
      }
    end

    it "returns payload body" do
      expect(subject).to eq(create_body)
    end
  end

  describe "#update_body" do
    subject(:body_call) { payload.update_body }

    let(:update_body) do
      {
        "objectId" => integration_subscription.external_id,
        "objectType" => integration.subscriptions_object_type_id,
        "input" => {
          "properties" => {
            "lago_subscription_id" => subscription.id,
            "lago_external_subscription_id" => subscription.external_id,
            "lago_billing_time" => subscription.billing_time,
            "lago_subscription_name" => subscription.name,
            "lago_subscription_plan_code" => subscription.plan.code,
            "lago_subscription_status" => subscription.status,
            "lago_subscription_created_at" => subscription.created_at.strftime("%Y-%m-%d"),
            "lago_subscription_started_at" => subscription.started_at&.strftime("%Y-%m-%d"),
            "lago_subscription_ending_at" => subscription.ending_at&.strftime("%Y-%m-%d"),
            "lago_subscription_at" => subscription.subscription_at&.strftime("%Y-%m-%d"),
            "lago_subscription_terminated_at" => subscription.terminated_at&.strftime("%Y-%m-%d"),
            "lago_subscription_trial_ended_at" => subscription.trial_ended_at&.strftime("%Y-%m-%d"),
            "lago_subscription_link" => subscription_url
          }
        }
      }
    end

    it "returns payload body" do
      expect(subject).to eq(update_body)
    end
  end

  describe "#customer_association_body" do
    subject(:body_call) { payload.customer_association_body }

    let(:customer_association_body) do
      {
        "objectType" => integration.subscriptions_object_type_id,
        "objectId" => integration_subscription.external_id,
        "toObjectType" => integration_customer.object_type,
        "toObjectId" => integration_customer.external_customer_id,
        "input" => []
      }
    end

    it "returns payload body" do
      expect(subject).to eq(customer_association_body)
    end
  end
end
