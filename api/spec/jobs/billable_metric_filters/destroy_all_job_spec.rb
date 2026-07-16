# frozen_string_literal: true

RSpec.describe BillableMetricFilters::DestroyAllJob do
  let(:billable_metric) { create(:billable_metric, :discarded) }

  it "destroys all filters and filter values" do
    allow(BillableMetricFilters::DestroyAllService)
      .to receive(:call!)
      .with(billable_metric)
      .and_return(BillableMetricFilters::DestroyAllService::Result.new)

    described_class.perform_now(billable_metric.id)

    expect(BillableMetricFilters::DestroyAllService).to have_received(:call!)
  end
end
