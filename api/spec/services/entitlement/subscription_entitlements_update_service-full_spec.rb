# frozen_string_literal: true

require "rails_helper"

RSpec.describe Entitlement::SubscriptionEntitlementsUpdateService do
  subject(:result) { described_class.call(subscription:, entitlements_params:, partial: false) }

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

  before do
    feature
    privilege
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

    it "creates the entitlement with correct values" do
      result
      entitlement = subscription.entitlements.first
      entitlement_value = entitlement.values.first

      expect(entitlement.feature).to eq(feature)
      expect(entitlement_value.privilege).to eq(privilege)
      expect(entitlement_value.value).to eq("25")
    end

    context "when plan already has the feature" do
      let(:existing_entitlement) { create(:entitlement, organization:, plan:, feature:) }
      let(:existing_value) { create(:entitlement_value, entitlement: existing_entitlement, privilege:, value: "10", organization:) }

      it "creates an override" do
        result

        expect(result).to be_success
        expect(existing_value.value).to eq "10"
        expect(subscription.entitlements.sole.values.sole.value).to eq("25")
      end
    end

    context "when plan already has the same feature and privilege values" do
      let(:existing_entitlement) { create(:entitlement, organization:, plan:, feature:) }
      let(:existing_value) { create(:entitlement_value, entitlement: existing_entitlement, privilege:, value: "25", organization:) }

      before { existing_value }

      it "does not create an override" do
        result

        expect(result).to be_success
        expect(existing_value.value).to eq "25"
        expect(subscription.entitlements.reload).to be_empty
      end

      context "when there is an override with a different value" do
        let(:existing_override_entitlement) { create(:entitlement, organization:, plan: nil, subscription:, feature:) }
        let(:existing_override_value) { create(:entitlement_value, entitlement: existing_override_entitlement, privilege:, value: "3453453", organization:) }

        it "removes the subscription override" do
          existing_override_value
          result

          expect(existing_override_entitlement.reload.deleted_at).to be_present
          expect(existing_override_value.reload.deleted_at).to be_present
          expect(subscription.entitlements.reload).to be_empty

          final_ent = Entitlement::SubscriptionEntitlement.for_subscription(subscription).find { it.code == "seats" }
          priv = final_ent.privileges.find { it.code == "max" }
          expect(priv.plan_value).to eq("25")
          expect(priv.subscription_value).to be_nil
        end
      end

      context "when feature was removed" do
        let(:removal) { create(:subscription_feature_removal, feature: existing_entitlement.feature, subscription:) }

        before { removal }

        it "removes the feature removal" do
          result

          expect(removal.reload.deleted_at).to be_present
          expect(subscription.entitlements.reload).to be_empty

          final_ent = Entitlement::SubscriptionEntitlement.for_subscription(subscription).find { it.code == "seats" }
          priv = final_ent.privileges.find { it.code == "max" }
          expect(priv.plan_value).to eq("25")
          expect(priv.subscription_value).to be_nil
        end

        context "when the value is different from plan" do
          let(:entitlements_params) do
            {
              "seats" => {
                "max" => 3
              }
            }
          end

          it "restore the feature and create an override" do
            result

            expect(removal.reload.deleted_at).to be_present
            expect(subscription.entitlements.reload.sole.values.sole.value).to eq "3"
          end
        end
      end
    end

    context "when subscription has existing entitlements" do
      let(:existing_entitlement) { create(:entitlement, organization:, subscription_id: subscription.id, plan: nil, feature:) }
      let(:existing_value) { create(:entitlement_value, entitlement: existing_entitlement, privilege:, value: "10", organization:) }

      before do
        existing_value
      end

      it "replaces existing entitlements" do
        result

        expect(result).to be_success
        expect(existing_value.reload.value).to eq("25")
      end
    end

    context "when plan has a feature but it's not part of the params anymore" do
      let(:existing_entitlement) { create(:entitlement, organization:, plan:, feature:) }
      let(:existing_value) { create(:entitlement_value, entitlement: existing_entitlement, privilege:, value: "10", organization:) }

      let(:entitlements_params) do
        {
          feature2.code => {
            privilege3.code => false
          }
        }
      end

      before do
        existing_value
      end

      it "creates a SuscriptionFeatureRemoval" do
        result
        expect(result).to be_success
        expect(existing_entitlement.reload.deleted_at).to be_nil
        expect(existing_value.reload.deleted_at).to be_nil
        expect(Entitlement::SubscriptionFeatureRemoval.where(feature:, subscription:).count).to eq(1)

        expect(Entitlement::SubscriptionEntitlement.for_subscription(subscription).map(&:code)).to eq([feature2.code])
      end
    end

    context "when subscription has an extra feature but it's not part of the params anymore" do
      let(:existing_entitlement) { create(:entitlement, organization:, plan: nil, subscription:, feature:) }
      let(:existing_value) { create(:entitlement_value, entitlement: existing_entitlement, privilege:, value: "10", organization:) }

      let(:entitlements_params) do
        {
          feature2.code => {
            privilege3.code => false
          }
        }
      end

      before do
        existing_value
      end

      it "removes the override" do
        result
        expect(result).to be_success
        expect(existing_entitlement.reload.deleted_at).to be_present
        expect(existing_value.reload.deleted_at).to be_present
        expect(Entitlement::SubscriptionFeatureRemoval.where(feature:, subscription:).count).to eq(0)

        expect(Entitlement::SubscriptionEntitlement.for_subscription(subscription).map(&:code)).to eq([feature2.code])
      end
    end

    context "when subscription has a feature override but one privilege is missing" do
      let(:entitlement) { create(:entitlement, feature: feature2, plan: nil, subscription:) }
      let(:entitlement_value2) { create(:entitlement_value, entitlement:, privilege: privilege2, value: "100") }
      let(:entitlement_value3) { create(:entitlement_value, entitlement:, privilege: privilege3, value: true) }

      let(:entitlements_params) do
        {
          feature2.code => {
            privilege3.code => false
          }
        }
      end

      before do
        entitlement_value2
        entitlement_value3
      end

      it "removes the privilege value" do
        result
        expect(entitlement_value2.reload.deleted_at).to be_present
        expect(entitlement_value3.reload.value).to eq("f")
      end
    end

    context "when subscription has a feature from plan but one privilege is missing" do
      let(:entitlement) { create(:entitlement, feature: feature2, plan:) }
      let(:entitlement_value2) { create(:entitlement_value, entitlement:, privilege: privilege2, value: "100") }
      let(:entitlement_value3) { create(:entitlement_value, entitlement:, privilege: privilege3, value: true) }

      let(:entitlements_params) do
        {
          feature2.code => {
            privilege3.code => false
          }
        }
      end

      before do
        entitlement_value2
        entitlement_value3
      end

      it "creates a privilege removal" do
        expect(subscription.entitlements.where(feature: feature2)).not_to exist
        result
        expect(subscription.entitlement_removals.where(privilege: privilege2)).to exist

        sub_ent = subscription.entitlements.where(feature: feature2).sole
        expect(sub_ent.values.sole.value).to eq("f")
      end
    end

    context "when plan has a feature with privilege but subscriptions has privilege removals" do
      let(:entitlement) { create(:entitlement, feature: feature2, plan:) }
      let(:entitlement_value2) { create(:entitlement_value, entitlement:, privilege: privilege2, value: "100") }
      let(:entitlement_value3) { create(:entitlement_value, entitlement:, privilege: privilege3, value: true) }

      let(:privilege2_removal) { create(:subscription_feature_removal, subscription:, privilege: privilege2) }
      let(:privilege3_removal) { create(:subscription_feature_removal, subscription:, privilege: privilege3) }

      before do
        entitlement_value2
        entitlement_value3
        privilege2_removal
        privilege3_removal
      end

      context "when the entire feature is removed" do
        let(:entitlements_params) { {} }

        it "discard the privilege removals and add the feature removal" do
          expect(Entitlement::SubscriptionEntitlement.for_subscription(subscription).sole.privileges).to be_empty
          result
          expect(Entitlement::SubscriptionEntitlement.for_subscription(subscription)).to be_empty
          expect(subscription.entitlements).to be_empty
          expect(privilege2_removal.reload).to be_discarded
          expect(privilege3_removal.reload).to be_discarded
          expect(subscription.entitlement_removals.where(feature: feature2)).to exist
        end
      end
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

    context "when privilege value is nil" do
      let(:entitlements_params) do
        {
          "seats" => {
            "max" => nil
          }
        }
      end

      it "returns a validation failure with privilege-prefixed errors" do
        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages).to eq({"privilege.value": ["value_is_mandatory"]})
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
