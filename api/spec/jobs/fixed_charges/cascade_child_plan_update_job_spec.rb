# frozen_string_literal: true

require "rails_helper"

RSpec.describe FixedCharges::CascadeChildPlanUpdateJob do
  subject(:perform) do
    described_class.perform_now(
      plan:,
      cascade_fixed_charges_payload:,
      timestamp:
    )
  end

  let(:organization) { create(:organization) }
  let(:parent_plan) { create(:plan, organization:) }
  let(:plan) { create(:plan, organization:, parent: parent_plan) }
  let(:add_on) { create(:add_on, organization:) }
  let(:parent_fixed_charge) { create(:fixed_charge, plan: parent_plan, add_on:, units: 10) }
  let(:timestamp) { Time.current.to_i }
  let(:cascade_fixed_charges_payload) do
    [
      {
        action: :create,
        parent_id: parent_fixed_charge.id,
        code: parent_fixed_charge.code,
        add_on_id: add_on.id,
        charge_model: "standard",
        units: 10,
        pay_in_advance: true,
        properties: {amount: "10"}
      }
    ]
  end

  before do
    allow(FixedCharges::CascadeChildPlanUpdateService).to receive(:call!).and_call_original
  end

  it "calls the cascade child plan update service with correct parameters" do
    perform

    expect(FixedCharges::CascadeChildPlanUpdateService)
      .to have_received(:call!)
      .with(
        plan:,
        cascade_fixed_charges_payload:,
        timestamp:
      )
      .once
  end
end
