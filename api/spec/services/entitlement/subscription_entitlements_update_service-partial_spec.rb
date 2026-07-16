# frozen_string_literal: true

require "rails_helper"

RSpec.describe Entitlement::SubscriptionEntitlementsUpdateService do
  subject(:result) { described_class.call(subscription:, entitlements_params:, partial: true) }

  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:plan) { create(:plan, organization:) }
  let(:subscription) { create(:subscription, organization:, customer:, plan:) }
  let(:feature) { create(:feature, organization:, code: "seats") }
  let(:privilege) { create(:privilege, organization:, feature:, code: "max", value_type: "integer") }
  let(:entitlements_params) do
    {
      "seats" => {
        "max" => 25
      }
    }
  end

  let(:feature2) { create(:feature, code: "storage", organization:) }
  let(:privilege2) { create(:privilege, feature: feature2, code: "limit", value_type: "integer") }
  let(:privilege3) { create(:privilege, feature: feature2, code: "allow_overage", value_type: "boolean") }
  let(:entitlement) { create(:entitlement, feature:, plan:) }
  let(:entitlement_value2) { create(:entitlement_value, entitlement:, privilege: privilege2, value: "100") }
  let(:entitlement_value3) { create(:entitlement_value, entitlement:, privilege: privilege3, value: true) }

  before do
    feature
    privilege
    entitlement_value2
    entitlement_value3
  end

  describe "#call", :premium do
    it "returns success" do
      expect(result).to be_success
    end

    it "creates entitlements for the subscription" do
      expect { result }.to change { subscription.entitlements.count }.by(1)
    end

    it "creates entitlement values" do
      expect { result }.to change(Entitlement::EntitlementValue, :count).by(1)
    end

    it "sends `subscription.updated` webhook" do
      expect { subject }.to have_enqueued_job_after_commit(SendWebhookJob).with("subscription.updated", subscription)
    end

    it "produces an activity log" do
      subject
      expect(Utils::ActivityLog).to have_produced("subscription.updated").after_commit.with(subscription)
    end

    it "creates the entitlement with correct values and leave existing untouched" do
      result

      expect(entitlement.reload.values.map(&:value)).to contain_exactly("100", "t")
      new_entitlement = subscription.entitlements.order(:created_at).last
      expect(new_entitlement.feature).to eq(feature)
      expect(new_entitlement.values.sole.privilege).to eq privilege
      expect(new_entitlement.values.sole.value).to eq "25"
    end

    context "when subscription does not exist" do
      let(:subscription) { nil }

      it "returns not found failure" do
        expect(result).not_to be_success
        expect(result.error.error_code).to eq("subscription_not_found")
      end
    end

    context "when feature does not exist" do
      let(:entitlements_params) do
        {
          "nonexistent_feature" => {
            "max" => 25
          }
        }
      end

      it "returns not found failure" do
        expect(result).not_to be_success
        expect(result.error.error_code).to eq("feature_not_found")
      end
    end

    context "when privilege does not exist" do
      let(:entitlements_params) do
        {
          "seats" => {
            "nonexistent_privilege" => 25
          }
        }
      end

      it "returns not found failure" do
        expect(result).not_to be_success
        expect(result.error.error_code).to eq("privilege_not_found")
      end
    end

    context "when value is invalid" do
      let(:entitlements_params) do
        {
          "seats" => {
            "max" => "invalid"
          }
        }
      end

      it "returns validation failure" do
        expect(result).not_to be_success
        expect(result.error.messages).to eq({max_privilege_value: ["value_is_invalid"]})
      end
    end
  end
end
