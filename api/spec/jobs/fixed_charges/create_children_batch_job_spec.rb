# frozen_string_literal: true

require "rails_helper"

RSpec.describe FixedCharges::CreateChildrenBatchJob do
  let(:add_on) { create(:add_on) }
  let(:organization) { add_on.organization }
  let(:plan) { create(:plan, organization:) }
  let(:fixed_charge) { create(:fixed_charge, plan:, add_on:, organization:) }
  let(:child_ids) { ["child-id"] }
  let(:payload) { {add_on_id: add_on.id, charge_model: "standard"} }

  before do
    allow(FixedCharges::CreateChildrenService).to receive(:call!)
  end

  it "calls the create children service" do
    described_class.perform_now(child_ids:, fixed_charge:, payload:)

    expect(FixedCharges::CreateChildrenService).to have_received(:call!).with(
      child_ids:,
      fixed_charge:,
      payload:
    )
  end
end
