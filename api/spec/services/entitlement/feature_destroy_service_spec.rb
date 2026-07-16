# frozen_string_literal: true

require "rails_helper"

RSpec.describe Entitlement::FeatureDestroyService do
  subject { described_class.call(feature:) }

  let(:organization) { create(:organization) }
  let(:feature) { create(:feature, organization:) }
  let(:privilege1) { create(:privilege, feature:, code: "max_admins", value_type: "integer") }
  let(:privilege2) { create(:privilege, feature:, code: "has_root", value_type: "boolean") }

  before do
    privilege1
    privilege2
    feature.reload
  end

  describe "#call", :premium do
    it "discards the feature" do
      expect { subject }.to change { feature.reload.discarded? }.from(false).to(true)
    end

    it "discards all privileges associated with the feature" do
      expect { subject }.to change(feature.privileges, :count).by(-2)
    end

    it "returns the feature in the result" do
      result = subject

      expect(result).to be_success
      expect(result.feature).to eq(feature)
    end

    it "sends feature.deleted webhook" do
      expect { subject }.to have_enqueued_job_after_commit(SendWebhookJob).with("feature.deleted", feature)
    end

    it "produces an activity log" do
      result = subject
      expect(Utils::ActivityLog).to have_produced("feature.deleted").after_commit.with(result.feature)
    end

    context "when feature is nil" do
      it "returns a not found failure" do
        result = described_class.call(feature: nil)

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::NotFoundFailure)
        expect(result.error.resource).to eq("feature")
      end
    end

    context "when feature is already discarded" do
      before { feature.discard! }

      it "still succeeds" do
        expect { subject }.to raise_error(Discard::RecordNotDiscarded)
      end
    end

    context "when feature has no privileges" do
      before do
        privilege1.discard!
        privilege2.discard!
      end

      it "still discards the feature successfully" do
        expect { subject }.to change { feature.reload.discarded? }.from(false).to(true)
      end
    end

    context "when feature is attached to a plan" do
      let(:entitlement) { create(:entitlement, feature:) }
      let(:privilege1_value) { create(:entitlement_value, entitlement:, privilege: privilege1, value: 10) }
      let(:privilege2_value) { create(:entitlement_value, entitlement:, privilege: privilege2, value: true) }

      before do
        privilege1_value
        privilege2_value
      end

      it "discard all values and entitlement and send webhooks" do
        expect { subject }.to change(feature.entitlement_values, :count).from(2).to(0)
          .and change(feature.entitlements, :count).from(1).to(0)
          .and have_enqueued_job(SendWebhookJob).with("feature.deleted", feature)
          .and have_enqueued_job(SendWebhookJob).with("plan.updated", entitlement.plan)
      end

      it "produces plan.updated logs" do
        subject
        expect(Utils::ActivityLog).to have_produced("plan.updated").after_commit.with(entitlement.plan)
      end
    end
  end
end
