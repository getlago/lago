# frozen_string_literal: true

require "rails_helper"

RSpec.describe BillableMetrics::DeleteEventsJob, type: :job do
  let(:billable_metric) { create(:billable_metric, :deleted) }

  before do
    allow(Events::DeleteForMetricService).to receive(:call!).and_call_original
  end

  it "delegates to Events::DeleteForMetricService" do
    described_class.perform_now(billable_metric)

    expect(Events::DeleteForMetricService).to have_received(:call!)
      .with(billable_metric: billable_metric)
  end
end
