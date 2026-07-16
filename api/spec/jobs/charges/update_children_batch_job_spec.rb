# frozen_string_literal: true

require "rails_helper"

RSpec.describe Charges::UpdateChildrenBatchJob do
  let(:charge) { create(:standard_charge) }
  let(:child_charge) { create(:standard_charge, parent_id: charge.id) }
  let(:child_charge2) { create(:standard_charge, parent_id: charge.id) }
  let(:old_parent_attrs) { charge.attributes }
  let(:old_parent_applied_pricing_unit_attrs) { charge.filters.map(&:attributes) }
  let(:child_ids) { [child_charge.id, child_charge2.id] }
  let(:params) do
    {
      properties: {}
    }
  end

  before do
    allow(Charges::UpdateChildrenService)
      .to receive(:call!)
      .with(charge:, child_ids:, params:, old_parent_attrs:, old_parent_applied_pricing_unit_attrs:)
      .and_call_original
  end

  it "calls the children service" do
    described_class.perform_now(child_ids:, params:, old_parent_attrs:, old_parent_applied_pricing_unit_attrs:)

    expect(Charges::UpdateChildrenService).to have_received(:call!)
  end
end
