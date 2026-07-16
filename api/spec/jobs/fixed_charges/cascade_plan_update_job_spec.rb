# frozen_string_literal: true

require "rails_helper"

RSpec.describe FixedCharges::CascadePlanUpdateJob do
  subject(:perform) do
    described_class.perform_now(
      plan:,
      cascade_fixed_charges_payload:,
      timestamp:
    )
  end

  let(:organization) { create(:organization) }
  let(:plan) { create(:plan, organization:) }
  let(:timestamp) { Time.current.to_i }
  let(:cascade_fixed_charges_payload) do
    [
      {
        action: :create,
        add_on_id: "addon_id",
        charge_model: "standard",
        units: 10,
        pay_in_advance: true,
        properties: {amount: "10"}
      }
    ]
  end

  context "when no children plans" do
    it "does not queue a job" do
      expect { perform }.not_to have_enqueued_job(FixedCharges::CascadeChildPlanUpdateJob)
    end
  end

  context "when plan has children plans but no active/pending subscriptions" do
    before do
      create(:subscription, :terminated, plan: create(:plan, organization:, parent: plan))
    end

    it "does not queue a job" do
      expect { perform }.not_to have_enqueued_job(FixedCharges::CascadeChildPlanUpdateJob)
    end
  end

  context "when plan has children plans with active/pending subscriptions" do
    let(:child_plan_1) { create(:plan, organization:, parent: plan) }
    let(:child_plan_2) { create(:plan, organization:, parent: plan) }

    before do
      create(:subscription, :active, plan: child_plan_1)
      create(:subscription, :pending, plan: child_plan_2)
    end

    it "queues a job for each child plan" do
      expect { perform }
        .to have_enqueued_job(FixedCharges::CascadeChildPlanUpdateJob).with(plan: child_plan_1, cascade_fixed_charges_payload:, timestamp:)
        .and have_enqueued_job(FixedCharges::CascadeChildPlanUpdateJob).with(plan: child_plan_2, cascade_fixed_charges_payload:, timestamp:)
    end
  end
end
