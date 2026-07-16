# frozen_string_literal: true

require "rails_helper"

Rspec.describe ChargeModels::CustomService do
  subject(:apply_custom_service) do
    described_class.apply(
      charge:,
      aggregation_result:,
      properties: charge.properties,
      period_ratio: 1.0
    )
  end

  let(:aggregation_result) { BaseService::Result.new }
  let(:aggregation) { 10 }
  let(:total_aggregated_units) { nil }
  let(:full_units_number) { BigDecimal("10.0") }

  let(:charge) { create(:custom_charge, billable_metric:) }
  let(:billable_metric) { create(:custom_billable_metric) }

  before do
    aggregation_result.aggregation = aggregation
    aggregation_result.total_aggregated_units = total_aggregated_units if total_aggregated_units
    aggregation_result.full_units_number = full_units_number if full_units_number
    aggregation_result.custom_aggregation = {amount: 20, units: BigDecimal("10.0")}
  end

  it "applies the charge model to the value" do
    expect(apply_custom_service.amount).to eq(20)
    expect(apply_custom_service.unit_amount).to eq(2)
  end
end
