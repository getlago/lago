# frozen_string_literal: true

require "rails_helper"

RSpec.describe Plans::PrepareDestroyService do
  subject(:prepare_destroy_service) { described_class.new(plan:) }

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:plan) { create(:plan, organization:) }

  describe "#call" do
    it "sets pending_deletion to true" do
      expect { prepare_destroy_service.call }.to change { plan.reload.pending_deletion }
        .from(false).to(true)
    end

    it "enqueues a Plans::DestroyJob" do
      prepare_destroy_service.call
      expect(Plans::DestroyJob).to have_been_enqueued.with(plan)
      expect(SendWebhookJob).to have_been_enqueued.with("plan.deleted", plan)
    end

    it "returns plan in the result" do
      result = prepare_destroy_service.call
      expect(result.plan).to eq(plan)
    end

    context "when plan is not found" do
      let(:plan) { nil }

      it "returns an error" do
        result = prepare_destroy_service.call

        expect(result).not_to be_success
        expect(result.error.error_code).to eq("plan_not_found")
      end
    end
  end
end
