# frozen_string_literal: true

require "rails_helper"

RSpec.describe FixedCharges::UpdateChildrenJob do
  let(:organization) { create(:organization) }
  let(:add_on) { create(:add_on, organization:) }
  let(:plan) { create(:plan, organization:) }
  let(:fixed_charge) { create(:fixed_charge, plan:, add_on:) }
  let(:child_plan1) { create(:plan, parent_id: plan.id, organization:) }
  let(:child_plan2) { create(:plan, parent_id: plan.id, organization:) }
  let(:child_fixed_charge) { create(:fixed_charge, parent_id: fixed_charge.id, plan: child_plan1, add_on:) }
  let(:child_fixed_charge2) { create(:fixed_charge, parent_id: fixed_charge.id, plan: child_plan2, add_on:) }
  let(:subscription) { create(:subscription, plan: child_plan1) }
  let(:subscription2) { create(:subscription, plan: child_plan2, status: :terminated) }
  let(:old_parent_attrs) { fixed_charge.attributes }
  let(:params) do
    {
      properties: {}
    }
  end

  before do
    child_plan1
    child_plan2
    subscription
    subscription2
    allow(FixedCharges::UpdateChildrenBatchJob)
      .to receive(:perform_later)
      .with(child_ids: [child_fixed_charge.id], params:, old_parent_attrs:)
      .and_call_original
  end

  it "calls the batch jobs" do
    described_class.perform_now(params:, old_parent_attrs:)

    expect(FixedCharges::UpdateChildrenBatchJob).to have_received(:perform_later).once
  end
end
