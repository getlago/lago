# frozen_string_literal: true

require "rails_helper"

RSpec.describe ChargeModels::StandardService do
  subject(:apply_standard_service) do
    described_class.apply(
      charge:,
      aggregation_result:,
      properties: charge.properties,
      period_ratio: 1.0
    )
  end

  before do
    aggregation_result.aggregation = aggregation
    aggregation_result.total_aggregated_units = total_aggregated_units if total_aggregated_units
    aggregation_result.full_units_number = full_units_number if full_units_number
  end

  let(:aggregation_result) { BaseService::Result.new }
  let(:aggregation) { 10 }
  let(:total_aggregated_units) { nil }
  let(:full_units_number) { nil }

  let(:charge) do
    create(
      :standard_charge,
      charge_model: "standard",
      properties: {
        amount: "5.12345"
      }
    )
  end

  it "applies the charge model to the value" do
    expect(apply_standard_service.amount).to eq(51.2345)
    expect(apply_standard_service.unit_amount).to eq(5.12345)
  end

  context "when aggregation result contains total_aggregated_units" do
    let(:total_aggregated_units) { 10 }

    it "assigns the total_aggregated_units to the result" do
      expect(apply_standard_service.total_aggregated_units).to eq(total_aggregated_units)
    end
  end

  context "when aggregation result contains full_units_number" do
    let(:full_units_number) { 100 }

    it "applies the charge model to the value" do
      expect(apply_standard_service.unit_amount).to eq(0.512345)
    end
  end

  context "when charge is a fixed charge" do
    let(:charge) { build(:fixed_charge, charge_model: :standard, properties: {amount: "10"}) }

    it "applies the charge model to the value" do
      expect(apply_standard_service.amount).to eq(100)
      expect(apply_standard_service.unit_amount).to eq(10)
    end
  end
end
