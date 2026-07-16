# frozen_string_literal: true

require "rails_helper"

RSpec.describe Entitlement::PlanEntitlementPrivilegeDestroyService do
  subject(:result) { described_class.call(entitlement:, privilege_code:) }

  let(:organization) { create(:organization) }
  let(:plan) { create(:plan, organization:) }
  let(:feature) { create(:feature, organization:) }
  let(:privilege) { create(:privilege, organization:, feature:, code: "max") }
  let(:privilege2) { create(:privilege, organization:, feature:, code: "max_admins") }
  let(:entitlement) { create(:entitlement, organization:, plan:, feature:) }
  let(:entitlement_value) { create(:entitlement_value, entitlement:, privilege:, organization:) }
  let(:entitlement_value2) { create(:entitlement_value, entitlement:, privilege: privilege2, organization:) }
  let(:privilege_code) { "max" }

  before do
    entitlement_value
    entitlement_value2
  end

  describe "#call", :premium do
    it "returns success" do
      expect(result).to be_success
    end

    it "soft deletes the specific entitlement value" do
      expect { result }.to change(feature.entitlement_values, :count).by(-1)
    end

    it "does not delete other entitlement values" do
      result
      expect(entitlement.values.kept.count).to eq(1)
      expect(entitlement.values.kept.first.privilege).to eq(privilege2)
    end

    it "returns the entitlement in the result" do
      expect(result.entitlement).to eq(entitlement)
      expect(result.entitlement.values).to be_loaded
      result.entitlement.values.all? do |value|
        expect(value.association(:privilege)).to be_loaded
      end
      expect(result.entitlement.values.ids).to contain_exactly(entitlement_value2.id)
    end

    it "sends `plan.updated` webhook" do
      expect { subject }.to have_enqueued_job_after_commit(SendWebhookJob).with("plan.updated", plan)
    end

    it "produces an activity log" do
      subject
      expect(Utils::ActivityLog).to have_produced("plan.updated").after_commit.with(plan)
    end

    context "when entitlement is nil" do
      subject(:result) { described_class.call(entitlement: nil, privilege_code: privilege_code) }

      it "returns not found failure" do
        expect(result).not_to be_success
        expect(result.error.error_code).to eq("entitlement_not_found")
      end
    end

    context "when privilege code does not exist" do
      let(:privilege_code) { "nonexistent" }

      it "returns not found failure" do
        expect(result).not_to be_success
        expect(result.error.error_code).to eq("privilege_not_found")
      end
    end

    context "when entitlement value is already deleted" do
      before do
        entitlement_value.discard!
      end

      it "returns not found failure" do
        expect(result).not_to be_success
        expect(result.error.error_code).to eq("privilege_not_found")
      end
    end
  end
end
