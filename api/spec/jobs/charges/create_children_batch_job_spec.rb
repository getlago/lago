# frozen_string_literal: true

require "rails_helper"

RSpec.describe Charges::CreateChildrenBatchJob do
  let(:billable_metric) { create(:billable_metric) }
  let(:plan) { create(:plan, organization: billable_metric.organization) }
  let(:child_plan) { create(:plan, organization: billable_metric.organization, parent_id: plan.id) }
  let(:charge) { create(:standard_charge, plan:, billable_metric:) }
  let(:child_ids) { [child_plan.id] }

  let(:params) do
    {
      billable_metric_id: billable_metric.id,
      charge_model: "standard",
      invoice_display_name: "charge1",
      min_amount_cents: 100
    }
  end

  before do
    allow(Charges::CreateChildrenService).to receive(:call!)
      .with(child_ids:, charge:, payload: params)
      .and_call_original
  end

  it "calls the batch service" do
    described_class.perform_now(child_ids:, charge:, payload: params)

    expect(Charges::CreateChildrenService).to have_received(:call!)
  end
end
