# frozen_string_literal: true

require "rails_helper"

RSpec.describe Entitlement::SubscriptionEntitlementUpdateService do
  subject(:result) do
    described_class.call(
      subscription:,
      feature_code: feature_code,
      privilege_params: privilege_params,
      partial: partial
    )
  end

  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:plan) { create(:plan, organization:) }
  let(:subscription) { create(:subscription, organization:, customer:, plan:) }

  let(:feature) { create(:feature, organization:, code: "seats") }
  let(:privilege) { create(:privilege, organization:, feature:, code: "max", value_type: "integer") }

  let(:feature_code) { feature.code }
  let(:privilege_params) { {"max" => 25} }
  let(:partial) { false }

  before do
    feature
    privilege
  end

  describe "#call", :premium do
    context "when successful" do
      let(:plan_entitlement) { create(:entitlement, organization:, plan:, feature: feature) }

      before do
        plan_entitlement

        allow(Entitlement::SubscriptionEntitlementCoreUpdateService).to receive(:call!).and_return(true)
      end

      it "calls the inner service with expected arguments" do
        result

        expect(Entitlement::SubscriptionEntitlementCoreUpdateService).to have_received(:call!).with(
          subscription: subscription,
          plan: plan, # no parent plan created here, so it's the subscription plan
          feature: feature,
          plan_entitlement:,
          sub_entitlement: nil,
          privilege_params: privilege_params.with_indifferent_access,
          partial: false
        )
      end

      it "sends `subscription.updated` webhook" do
        expect { subject }.to have_enqueued_job_after_commit(SendWebhookJob).with("subscription.updated", subscription)
      end

      it "produces an activity log" do
        subject
        expect(Utils::ActivityLog).to have_produced("subscription.updated").after_commit.with(subscription)
      end

      it "returns success" do
        expect(result).to be_success
      end
    end

    context "when subscription is nil" do
      let(:subscription) { nil }

      it "returns not found failure for subscription" do
        expect(result).not_to be_success
        expect(result.error.error_code).to eq("subscription_not_found")
      end
    end

    context "when feature is not found" do
      let(:feature_code) { "nonexistent_feature" }

      it "returns not found failure for feature and does not call inner service" do
        allow(Entitlement::SubscriptionEntitlementCoreUpdateService).to receive(:call!).and_return(true)
        expect(result).not_to be_success
        expect(result.error.error_code).to eq("feature_not_found")
        expect(Entitlement::SubscriptionEntitlementCoreUpdateService).not_to have_received(:call!)
      end
    end

    context "when privilege is not found" do
      before do
        allow(Entitlement::SubscriptionEntitlementCoreUpdateService).to receive(:call!).and_raise(
          ActiveRecord::RecordNotFound.new("Couldn't find Entitlement::Privilege")
        )
      end

      it "returns not found failure for privilege" do
        expect(result).not_to be_success
        expect(result.error.error_code).to eq("privilege_not_found")
      end
    end

    context "when value is invalid" do
      let(:privilege_params) do
        {
          "max" => "invalid"
        }
      end

      it "returns validation failure" do
        expect(result).not_to be_success
        expect(result.error.messages).to eq({max_privilege_value: ["value_is_invalid"]})
      end
    end
  end
end
