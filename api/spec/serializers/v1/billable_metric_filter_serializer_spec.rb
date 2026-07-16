# frozen_string_literal: true

require "rails_helper"

RSpec.describe ::V1::BillableMetricFilterSerializer do
  subject(:serializer) { described_class.new(billable_metric_filter, root_name: "billable_metric_filter") }

  let(:billable_metric_filter) { create(:billable_metric_filter) }
  let(:result) { JSON.parse(serializer.to_json) }

  it "serializes the object" do
    expect(result["billable_metric_filter"]).to include(
      "key" => billable_metric_filter.key,
      "values" => billable_metric_filter.values.sort
    )
  end
end
