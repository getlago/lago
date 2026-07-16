# frozen_string_literal: true

require "rails_helper"

RSpec.describe FixedCharges::CreateChildrenJob do
  let(:add_on) { create(:add_on) }
  let(:organization) { add_on.organization }
  let(:plan) { create(:plan, organization:) }
  let(:child_plan) { create(:plan, organization:, parent_id: plan.id) }
  let(:child_plan2) { create(:plan, organization:, parent_id: plan.id) }
  let(:subscription) { create(:subscription, plan: child_plan) }
  let(:subscription2) { create(:subscription, plan: child_plan2, status: :terminated) }
  let(:fixed_charge) { create(:fixed_charge, plan:, add_on:, organization:) }
  let(:child_ids) { [child_plan.id] }

  let(:params) do
    {
      add_on_id: add_on.id,
      charge_model: "standard",
      invoice_display_name: "fixed_charge1"
    }
  end

  before do
    subscription
    subscription2
    child_plan2
    allow(FixedCharges::CreateChildrenBatchJob).to receive(:perform_later)
      .with(child_ids:, fixed_charge:, payload: params)
      .and_call_original
  end

  it "calls the batch job" do
    described_class.perform_now(fixed_charge:, payload: params)

    expect(FixedCharges::CreateChildrenBatchJob).to have_received(:perform_later).once
  end
end
