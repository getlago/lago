# frozen_string_literal: true

require "rails_helper"

RSpec.describe Webhooks::Subscriptions::StartedService do
  subject(:webhook_service) { described_class.new(object: subscription) }

  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:plan) { create(:plan, organization:) }
  let(:subscription) { create(:subscription, customer:, plan:, organization:) }

  describe ".call" do
    it_behaves_like "creates webhook", "subscription.started", "subscription", {
      "lago_id" => String,
      "external_id" => String,
      "lago_customer_id" => String,
      "external_customer_id" => String,
      "plan_code" => String,
      "status" => String,
      "billing_time" => String,
      "started_at" => String,
      "created_at" => String,
      "customer" => Hash,
      "entitlements" => Array,
      "payment_method" => Hash
    }

    context "with entitlements" do
      let(:feature) { create(:feature, organization:) }
      let(:privilege) { create(:privilege, feature:, organization:, value_type: "string") }
      let(:plan_entitlement) { create(:entitlement, feature:, plan:, organization:) }

      before do
        create(:entitlement_value, entitlement: plan_entitlement, privilege:, organization:, value: "enabled")
      end

      it "includes entitlements in the payload" do
        webhook_service.call

        webhook = Webhook.order(created_at: :desc).first
        entitlements = webhook.payload["subscription"]["entitlements"]

        expect(entitlements).to be_a(Array)
        expect(entitlements.size).to eq(1)
        expect(entitlements.first).to include(
          "code" => feature.code,
          "name" => feature.name,
          "description" => feature.description,
          "privileges" => a_collection_containing_exactly(
            hash_including(
              "code" => privilege.code,
              "value" => "enabled",
              "value_type" => "string"
            )
          )
        )
      end
    end
  end
end
