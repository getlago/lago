# frozen_string_literal: true

require "rails_helper"

RSpec.describe ChargeModels::DynamicService do
  subject(:apply_dynamic_service) do
    described_class.apply(
      charge:,
      aggregation_result:,
      properties: charge.properties,
      period_ratio: 1.0
    )
  end

  before do
    aggregation_result.aggregation = aggregation
    aggregation_result.precise_total_amount_cents = precise_total_amount_cents
  end

  let(:aggregation_result) { BaseService::Result.new }

  let(:charge) { create(:dynamic_charge) }

  let(:aggregation) { 20 }
  let(:precise_total_amount_cents) { BigDecimal("40.2") }

  it "applies the model to the values" do
    expect(apply_dynamic_service.amount).to eq(0.402)
    expect(apply_dynamic_service.unit_amount).to eq(0.0201)
  end

  context "when aggregation is zero" do
    let(:aggregation) { 0 }

    it "applies the model to the values" do
      expect(apply_dynamic_service.amount).to eq(0)
      expect(apply_dynamic_service.unit_amount).to eq(0)
    end
  end
end
