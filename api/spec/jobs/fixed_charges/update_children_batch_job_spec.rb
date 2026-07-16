# frozen_string_literal: true

require "rails_helper"

RSpec.describe FixedCharges::UpdateChildrenBatchJob do
  let(:organization) { create(:organization) }
  let(:add_on) { create(:add_on, organization:) }
  let(:plan) { create(:plan, organization:) }
  let(:fixed_charge) { create(:fixed_charge, plan:, add_on:) }
  let(:child_fixed_charge) { create(:fixed_charge, parent_id: fixed_charge.id, add_on:) }
  let(:child_fixed_charge2) { create(:fixed_charge, parent_id: fixed_charge.id, add_on:) }
  let(:old_parent_attrs) { fixed_charge.attributes }
  let(:child_ids) { [child_fixed_charge.id, child_fixed_charge2.id] }
  let(:params) do
    {
      properties: {}
    }
  end

  before do
    allow(FixedCharges::UpdateChildrenService)
      .to receive(:call!)
      .with(fixed_charge:, child_ids:, params:, old_parent_attrs:)
      .and_call_original
  end

  it "calls the children service" do
    described_class.perform_now(child_ids:, params:, old_parent_attrs:)

    expect(FixedCharges::UpdateChildrenService).to have_received(:call!)
  end
end
