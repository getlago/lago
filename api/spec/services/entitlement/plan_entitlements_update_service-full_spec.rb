# frozen_string_literal: true

require "rails_helper"

RSpec.describe Entitlement::PlanEntitlementsUpdateService do
  subject(:result) { described_class.call(organization:, plan:, entitlements_params:, partial: false) }

  let(:organization) { create(:organization) }
  let(:plan) { create(:plan, organization:) }
  let(:feature) { create(:feature, organization:, code: "seats") }
  let(:privilege) { create(:privilege, organization:, feature:, code: "max", value_type: "integer") }
  let(:entitlements_params) do
    {
      "seats" => {
        "max" => 25
      }
    }
  end

  before do
    feature
    privilege
  end

  describe "#call", :premium do
    it "returns success" do
      expect(result).to be_success
    end

    it "creates entitlements for the plan" do
      expect { result }.to change { plan.entitlements.count }.by(1)
    end

    it "creates entitlement values" do
      expect { result }.to change(Entitlement::EntitlementValue, :count).by(1)
    end

    it "returns the entitlements in the result" do
      expect(result.entitlements).to be_present
      expect(result.entitlements.count).to eq(1)
    end

    it "sends `plan.updated` webhook" do
      expect { subject }.to have_enqueued_job_after_commit(SendWebhookJob).with("plan.updated", plan)
    end

    it "produces an activity log" do
      subject
      expect(Utils::ActivityLog).to have_produced("plan.updated").after_commit.with(plan)
    end

    context "when send_webhook is false" do
      subject(:result) { described_class.call(organization:, plan:, entitlements_params:, partial: false, send_webhook: false) }

      it "does not send the `plan.updated` webhook" do
        expect { subject }.not_to have_enqueued_job(SendWebhookJob).with("plan.updated", plan)
      end

      it "does not produce an activity log" do
        subject
        expect(Utils::ActivityLog).not_to have_received(:produce)
      end
    end

    it "creates the entitlement with correct values" do
      result
      entitlement = plan.entitlements.first
      entitlement_value = entitlement.values.first

      expect(entitlement.feature).to eq(feature)
      expect(entitlement_value.privilege).to eq(privilege)
      expect(entitlement_value.value).to eq("25")
    end

    context "when plan has existing entitlements" do
      let(:existing_entitlement) { create(:entitlement, organization:, plan:) }
      let(:existing_value) { create(:entitlement_value, entitlement: existing_entitlement, privilege:, value: "10", organization:) }

      before do
        existing_entitlement
        existing_value
      end

      it "deletes existing entitlements and their values" do
        result
        expect(existing_value.reload.deleted_at).to be_present
        expect(existing_entitlement.reload.deleted_at).to be_present
      end

      it "creates new entitlements" do
        result
        new_entitlement = plan.entitlements.sole
        new_value = new_entitlement.values.sole

        expect(new_entitlement).not_to eq(existing_entitlement)
        expect(new_value.value).to eq("25")
      end
    end

    context "when entitlements_params is empty" do
      let(:entitlements_params) { {} }

      it "returns success" do
        expect(result).to be_success
      end

      it "does not create any entitlements" do
        expect { result }.not_to change { plan.entitlements.count }
      end
    end

    context "when feature has multiple privileges" do
      let(:privilege2) { create(:privilege, organization:, feature:, code: "max_admins", value_type: "integer") }
      let(:entitlements_params) do
        {
          "seats" => {
            "max" => 25,
            "max_admins" => 5
          }
        }
      end

      before do
        privilege2
      end

      it "creates entitlement values for all privileges" do
        expect { result }.to change(Entitlement::EntitlementValue, :count).by(2)
      end

      it "creates correct values for each privilege" do
        result
        entitlement = plan.entitlements.first
        values = entitlement.values.index_by(&:privilege)

        expect(values[privilege].value).to eq("25")
        expect(values[privilege2].value).to eq("5")
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

    context "when plan is nil" do
      subject(:result) { described_class.call(organization:, plan: nil, entitlements_params:, partial: false) }

      it "returns not found failure" do
        expect(result).not_to be_success
        expect(result.error.error_code).to eq("plan_not_found")
      end
    end

    context "when feature has no privileges in payload" do
      let(:entitlements_params) do
        {
          "seats" => {}
        }
      end

      it "creates entitlement without values" do
        expect { result }.to change { plan.entitlements.count }.by(1).and(not_change(Entitlement::EntitlementValue, :count))
      end
    end

    context "when value is boolean" do
      let(:privilege) { create(:privilege, organization:, feature:, code: "enabled", value_type: "boolean") }
      let(:entitlements_params) do
        {
          "seats" => {
            "enabled" => true
          }
        }
      end

      it "converts boolean to string" do
        result
        entitlement_value = plan.entitlements.first.values.first
        expect(entitlement_value.value).to eq("t")
      end
    end

    context "when value is string" do
      let(:privilege) { create(:privilege, organization:, feature:, code: "provider", value_type: "string") }
      let(:entitlements_params) do
        {
          "seats" => {
            "provider" => "okta"
          }
        }
      end

      it "converts string to string" do
        result
        entitlement_value = plan.entitlements.first.values.first
        expect(entitlement_value.value).to eq("okta")
      end
    end

    context "when privilege value is invalid" do
      let(:entitlements_params) do
        {
          "seats" => {
            "max" => [12, 13]
          }
        }
      end

      it "returns validation failure" do
        expect(result).not_to be_success
        expect(result.error).to be_a BaseService::ValidationFailure
        expect(result.error.messages[:max_privilege_value]).to eq(["value_is_invalid"])
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

    context "when privilege value is not in select_options" do
      let(:privilege) { create(:privilege, organization:, feature:, code: "invitation", value_type: "select", config: {select_options: ["email", "phone", "slack"]}) }
      let(:entitlements_params) do
        {
          "seats" => {
            "invitation" => "okta"
          }
        }
      end

      it "returns validation failure" do
        expect(result).not_to be_success
        expect(result.error).to be_a BaseService::ValidationFailure
        expect(result.error.messages[:invitation_privilege_value]).to eq(["value_not_in_select_options"])
      end
    end

    context "with bullet gem to detect N+1 queries", bullet: {unused_eager_loading: false} do
      context "when updating multiple features with multiple privileges" do
        let(:feature) { create(:feature, organization:) }
        let(:feature2) { create(:feature, organization:, code: "storage") }
        let(:feature3) { create(:feature, organization:, code: "api") }
        let(:privilege) { create(:privilege, feature:, code: "max", value_type: "integer") }
        let(:privilege2) { create(:privilege, feature:, code: "max_admins", value_type: "integer") }
        let(:privilege3) { create(:privilege, organization:, feature: feature2, code: "max_storage", value_type: "integer") }
        let(:privilege4) { create(:privilege, organization:, feature: feature2, code: "max_bandwidth", value_type: "integer") }
        let(:privilege5) { create(:privilege, organization:, feature: feature3, code: "max_requests", value_type: "integer") }
        let(:privilege6) { create(:privilege, organization:, feature: feature3, code: "max_rate_limit", value_type: "integer") }
        let(:entitlement2) { create(:entitlement, organization:, plan:, feature: feature2) }
        let(:entitlement3) { create(:entitlement, organization:, plan:, feature: feature3) }
        let(:entitlement_value2) { create(:entitlement_value, entitlement: entitlement2, privilege: privilege3, organization:, value: "100") }
        let(:entitlement_value3) { create(:entitlement_value, entitlement: entitlement3, privilege: privilege5, organization:, value: "1000") }
        let(:entitlements_params) do
          {
            feature.code => {
              privilege.code => 60,
              privilege2.code => 5
            },
            feature2.code => {
              privilege3.code => 200,
              privilege4.code => 50
            },
            feature3.code => {
              privilege5.code => 2000,
              privilege6.code => 100
            }
          }
        end

        before do
          feature2
          feature3
          privilege3
          privilege4
          privilege5
          privilege6
          entitlement2
          entitlement3
          entitlement_value2
          entitlement_value3

          allow(SendWebhookJob).to receive(:perform_after_commit)
        end

        it "does not trigger N+1 queries when updating multiple features and privileges" do
          result

          expect(result).to be_success
          expect(result.entitlements.count).to eq(3)
        end
      end
    end
  end
end
