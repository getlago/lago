# frozen_string_literal: true

require "rails_helper"

RSpec.describe Charges::UpdateChildrenJob do
  let(:charge) { create(:standard_charge) }
  let(:child_plan1) { create(:plan, parent_id: charge.plan.id) }
  let(:child_plan2) { create(:plan, parent_id: charge.plan.id) }
  let(:child_charge) { create(:standard_charge, parent_id: charge.id, plan: child_plan1) }
  let(:child_charge2) { create(:standard_charge, parent_id: charge.id, plan: child_plan2) }
  let(:subscription) { create(:subscription, plan: child_plan1) }
  let(:subscription2) { create(:subscription, plan: child_plan2, status: :terminated) }
  let(:old_parent_attrs) { charge.attributes }
  let(:old_parent_applied_pricing_unit_attrs) { charge.filters.map(&:attributes) }
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
    allow(Charges::UpdateChildrenBatchJob)
      .to receive(:perform_later)
      .with(child_ids: [child_charge.id], params:, old_parent_attrs:, old_parent_applied_pricing_unit_attrs:)
      .and_call_original
  end

  it "calls the batch jobs" do
    described_class.perform_now(params:, old_parent_attrs:, old_parent_applied_pricing_unit_attrs:)

    expect(Charges::UpdateChildrenBatchJob).to have_received(:perform_later).once
  end
end
