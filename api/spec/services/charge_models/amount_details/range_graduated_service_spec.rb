# frozen_string_literal: true

require "rails_helper"

RSpec.describe ChargeModels::AmountDetails::RangeGraduatedService do
  subject(:service) { described_class.new(range:, total_units:) }

  let(:total_units) { 15 }
  let(:range) do
    {
      from_value: 0,
      to_value: 10,
      per_unit_amount: "10",
      flat_amount: "2"
    }
  end

  it "returns expected amount details" do
    expect(service.call).to eq(
      {
        from_value: 0,
        to_value: 10,
        flat_unit_amount: 2,
        per_unit_amount: 10,
        units: "10.0",
        per_unit_total_amount: 100,
        total_with_flat_amount: 102
      }
    )
  end

  context "when total units <= range to_value" do
    let(:range) do
      {
        from_value: 11,
        to_value: 20,
        per_unit_amount: "8",
        flat_amount: "1"
      }
    end

    it "returns expected amount details" do
      expect(service.call).to eq(
        {
          from_value: 11,
          to_value: 20,
          flat_unit_amount: 1,
          per_unit_amount: 8,
          units: "5.0",
          per_unit_total_amount: 40,
          total_with_flat_amount: 41
        }
      )
    end
  end

  context "with decimal adjacent model" do
    subject(:service) { described_class.new(range:, total_units:, adjacent_model: true) }

    context "when total units exhaust the tier" do
      let(:total_units) { 1.5 }
      let(:range) do
        {from_value: 0.1, to_value: 1, per_unit_amount: "5", flat_amount: "0"}
      end

      it "returns to_value - from_value as units" do
        expect(service.call[:units]).to eq("0.9")
        expect(service.call[:per_unit_total_amount]).to eq(BigDecimal("4.5"))
      end
    end

    context "when total units are within the tier" do
      let(:total_units) { 0.5 }
      let(:range) do
        {from_value: 0.1, to_value: 2, per_unit_amount: "5", flat_amount: "0"}
      end

      it "returns total_units - from_value as units" do
        expect(service.call[:units]).to eq("0.4")
        expect(service.call[:per_unit_total_amount]).to eq(BigDecimal("2.0"))
      end
    end

    context "when from_value is zero" do
      let(:total_units) { 0.05 }
      let(:range) do
        {from_value: 0, to_value: 0.1, per_unit_amount: "10", flat_amount: "0"}
      end

      it "returns total_units as units" do
        expect(service.call[:units]).to eq("0.05")
        expect(service.call[:per_unit_total_amount]).to eq(BigDecimal("0.5"))
      end
    end
  end
end
