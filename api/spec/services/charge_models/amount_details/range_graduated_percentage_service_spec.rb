# frozen_string_literal: true

require "rails_helper"

RSpec.describe ChargeModels::AmountDetails::RangeGraduatedPercentageService do
  subject(:service) { described_class.new(range:, total_units:) }

  let(:total_units) { 15 }
  let(:range) do
    {
      from_value: 7,
      to_value: 10,
      rate: "2.9",
      flat_amount: "2"
    }
  end

  it "returns expected amount details" do
    expect(service.call).to eq(
      {
        from_value: 7,
        to_value: 10,
        flat_unit_amount: 2,
        rate: 2.9,
        units: "4.0",
        per_unit_total_amount: "0.116",
        total_with_flat_amount: 2.116
      }
    )
  end

  context "when total units <= range to_value" do
    let(:range) do
      {
        from_value: 11,
        to_value: 20,
        rate: "1",
        flat_amount: "1"
      }
    end

    it "returns expected amount details" do
      expect(service.call).to eq(
        {
          from_value: 11,
          to_value: 20,
          flat_unit_amount: 1,
          rate: 1,
          units: "5.0",
          per_unit_total_amount: "0.05",
          total_with_flat_amount: 1.05
        }
      )
    end
  end
end
