# frozen_string_literal: true

require "rails_helper"

RSpec.describe Entitlement::PrivilegeDestroyService do
  subject { described_class.call(privilege:) }

  let(:organization) { create(:organization) }
  let(:feature) { create(:feature, organization:) }
  let(:privilege) { create(:privilege, feature:, code: "max_admins", value_type: "integer") }

  before do
    privilege.reload
  end

  describe "#call", :premium do
    it "discards the privilege" do
      expect { subject }.to change { privilege.reload.discarded? }.from(false).to(true)
    end

    it "returns the privilege in the result" do
      result = subject

      expect(result).to be_success
      expect(result.privilege).to eq(privilege)
    end

    it "sends feature.updated webhook" do
      expect { subject }.to have_enqueued_job_after_commit(SendWebhookJob).with("feature.updated", feature)
    end

    it "produces an activity log" do
      subject
      expect(Utils::ActivityLog).to have_produced("feature.updated").after_commit.with(feature)
    end

    context "when privilege is nil" do
      it "returns a not found failure" do
        result = described_class.call(privilege: nil)

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::NotFoundFailure)
        expect(result.error.resource).to eq("privilege")
      end
    end

    context "when privilege is already discarded" do
      before { privilege.discard! }

      it "still succeeds" do
        expect { subject }.to raise_error(Discard::RecordNotDiscarded)
      end
    end

    context "when privilege has entitlements" do
      let(:entitlement) { create(:entitlement, feature:) }
      let(:entitlement_value) { create(:entitlement_value, entitlement:, privilege:, value: "10") }

      before do
        entitlement_value
      end

      it "discards all related entitlement values" do
        expect { subject }.to change(Entitlement::EntitlementValue, :count).by(-1)
      end

      it "sends `plan.updated` webhook" do
        expect { subject }.to have_enqueued_job_after_commit(SendWebhookJob).with("plan.updated", entitlement.plan)
      end

      it "produces plan.updated logs" do
        subject
        expect(Utils::ActivityLog).to have_produced("plan.updated").after_commit.with(entitlement.plan)
      end
    end
  end
end
