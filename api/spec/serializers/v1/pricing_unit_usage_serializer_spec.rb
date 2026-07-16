# frozen_string_literal: true

require "rails_helper"

RSpec.describe ::V1::PricingUnitUsageSerializer do
  subject(:serializer) { described_class.new(pricing_unit_usage, root_name: "pricing_unit_usage") }

  let(:pricing_unit_usage) { create(:pricing_unit_usage) }
  let(:result) { JSON.parse(serializer.to_json) }

  it "serializes the pricing unit usage" do
    expect(result["pricing_unit_usage"]).to include(
      "lago_pricing_unit_id" => pricing_unit_usage.pricing_unit_id,
      "pricing_unit_code" => pricing_unit_usage.pricing_unit.code,
      "short_name" => pricing_unit_usage.short_name,
      "amount_cents" => pricing_unit_usage.amount_cents,
      "precise_amount_cents" => pricing_unit_usage.precise_amount_cents.to_s,
      "unit_amount_cents" => pricing_unit_usage.unit_amount_cents,
      "precise_unit_amount" => pricing_unit_usage.precise_unit_amount.to_s,
      "conversion_rate" => pricing_unit_usage.conversion_rate.to_s
    )
  end
end
