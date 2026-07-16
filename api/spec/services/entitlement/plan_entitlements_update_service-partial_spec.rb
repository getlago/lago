# frozen_string_literal: true

require "rails_helper"

RSpec.describe Entitlement::PlanEntitlementsUpdateService do
  subject(:result) { described_class.call(organization:, plan:, entitlements_params:, partial: true) }

  let(:organization) { create(:organization) }
  let(:plan) { create(:plan, organization:) }
  let(:feature) { create(:feature, organization:) }
  let(:privilege) { create(:privilege, feature:, code: "max", value_type: "integer") }
  let(:privilege2) { create(:privilege, feature:, code: "max_admins", value_type: "integer") }
  let(:entitlement) { create(:entitlement, plan:, feature:) }
  let(:entitlement_value) { create(:entitlement_value, entitlement:, privilege:, organization:, value: 10) }
  let(:entitlements_params) do
    {
      feature.code => {
        privilege.code => 60
      }
    }
  end

  before do
    privilege
    privilege2
    entitlement
    entitlement_value
  end

  describe "#call", :premium do
    it "returns success" do
      expect(result).to be_success
    end

    it "updates existing entitlement value" do
      expect { result }.to change { entitlement_value.reload.value }.from("10").to("60")
    end

    it "does not create new entitlement" do
      expect { result }.not_to change(Entitlement::Entitlement, :count)
    end

    it "does not create new entitlement value" do
      expect { result }.not_to change(Entitlement::EntitlementValue, :count)
    end

    it "returns entitlements in the result" do
      expect(result.entitlements).to include(entitlement)
    end

    it "sends `plan.updated` webhook" do
      expect { subject }.to have_enqueued_job_after_commit(SendWebhookJob).with("plan.updated", plan)
    end

    it "produces an activity log" do
      subject
      expect(Utils::ActivityLog).to have_produced("plan.updated").after_commit.with(plan)
    end

    context "when privilege value does not exist" do
      let(:entitlements_params) do
        {
          feature.code => {
            privilege2.code => 30
          }
        }
      end

      it "creates new entitlement value" do
        expect { result }.to change(Entitlement::EntitlementValue, :count).by(1)
      end

      it "creates entitlement value with correct attributes" do
        ent_value = result.entitlements.find { it.entitlement_feature_id == feature.id }
          .values.find { it.entitlement_privilege_id == privilege2.id }

        expect(ent_value.value).to eq("30")
      end
    end

    context "when entitlement does not exist" do
      let(:new_feature) { create(:feature, organization:) }
      let(:new_privilege) { create(:privilege, organization:, feature: new_feature, code: "max_users", value_type: "integer") }
      let(:entitlements_params) do
        {
          new_feature.code => {
            new_privilege.code => 50
          }
        }
      end

      it "creates new entitlement" do
        expect { result }.to change(Entitlement::Entitlement, :count).by(1)
      end

      it "creates new entitlement value" do
        expect { result }.to change(Entitlement::EntitlementValue, :count).by(1)
      end

      it "creates entitlement with correct attributes" do
        ent_value = result.entitlements.find { it.entitlement_feature_id == new_feature.id }
          .values.find { it.entitlement_privilege_id == new_privilege.id }

        expect(ent_value.value).to eq("50")
        expect(ent_value.organization).to eq(organization)
        expect(ent_value.entitlement.plan).to eq(plan)
        expect(ent_value.entitlement.feature).to eq(new_feature)
        expect(ent_value.entitlement.organization).to eq(organization)
      end
    end

    context "when updating multiple features" do
      let(:feature2) { create(:feature, organization:) }
      let(:privilege3) { create(:privilege, organization:, feature: feature2, code: "max_storage", value_type: "integer") }
      let(:entitlement2) { create(:entitlement, organization:, plan:, feature: feature2) }
      let(:entitlement_value2) { create(:entitlement_value, entitlement: entitlement2, privilege: privilege3, organization:, value: "100") }
      let(:entitlements_params) do
        {
          feature.code => {
            privilege.code => 60
          },
          feature2.code => {
            privilege3.code => 200
          }
        }
      end

      before do
        entitlement2
        entitlement_value2
      end

      it "updates both entitlement values" do
        result
        expect(entitlement_value.reload.value).to eq("60")
        expect(entitlement_value2.reload.value).to eq("200")
      end

      it "returns both entitlements in the result" do
        expect(result.entitlements).to include(entitlement, entitlement2)
      end
    end

    context "when plan is nil" do
      let(:result) { described_class.call(organization:, plan: nil, entitlements_params:, partial: true) }

      it "returns not found failure" do
        expect(result).not_to be_success
        expect(result.error.error_code).to eq("plan_not_found")
      end
    end

    context "when feature does not exist" do
      let(:entitlements_params) do
        {
          "nonexistent_feature" => {
            privilege.code => 60
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
          feature.code => {
            "nonexistent_privilege" => 60
          }
        }
      end

      it "returns not found failure" do
        expect(result).not_to be_success
        expect(result.error.error_code).to eq("privilege_not_found")
      end
    end

    context "when value is invalid for select privilege" do
      let(:select_privilege) { create(:privilege, organization:, feature:, code: "provider", value_type: "select", config: {"select_options" => ["okta", "ad"]}) }
      let(:entitlements_params) do
        {
          feature.code => {
            select_privilege.code => "invalid_option"
          }
        }
      end

      it "returns validation failure" do
        expect(result).not_to be_success
        expect(result.error.messages[:provider_privilege_value]).to eq ["value_not_in_select_options"]
      end
    end

    context "when entitlements_params is empty" do
      let(:entitlements_params) { {} }

      it "returns success" do
        expect(result).to be_success
      end

      it "does not change any entitlement values" do
        expect { result }.not_to change { entitlement_value.reload.value }
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
