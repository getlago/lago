# frozen_string_literal: true

require "rails_helper"

RSpec.describe Charges::PayInAdvance::AmountDetailsCalculator do
  let(:amount_details_calculator) { described_class.new(charge:, applied_charge_model:, applied_charge_model_excluding_event:) }

  let(:charge) { create(:standard_charge, :pay_in_advance) }
  let(:applied_charge_model) { instance_double("AppliedChargeModel", amount_details: all_charges_details) }
  let(:applied_charge_model_excluding_event) { instance_double("AppliedChargeModel", amount_details: charges_details_without_last_event) }

  context "when charge model does not support pay in advance amount details" do
    let(:all_charges_details) { nil }
    let(:charges_details_without_last_event) { nil }

    it "returns an empty hash" do
      expect(amount_details_calculator.call).to eq({})
    end
  end

  context "when charge model is percentage" do
    let(:charge) { create(:percentage_charge, :pay_in_advance) }
    let(:charge_model) { "percentage" }
    let(:all_charges_details) do
      {
        rate: 0.1,
        fixed_fee_unit_amount: 100,
        units: 10,
        free_units: 2,
        paid_units: 8,
        free_events: 1,
        paid_events: 9,
        fixed_fee_total_amount: 1000,
        min_max_adjustment_total_amount: 50,
        per_unit_total_amount: 800
      }
    end
    let(:charges_details_without_last_event) do
      {
        rate: 0.1,
        fixed_fee_unit_amount: 100,
        units: 8,
        free_units: 1,
        paid_units: 7,
        free_events: 1,
        paid_events: 8,
        fixed_fee_total_amount: 800,
        min_max_adjustment_total_amount: 40,
        per_unit_total_amount: 700
      }
    end

    it "calculates percentage charge details" do
      expected_details = {
        rate: 0.1,
        fixed_fee_unit_amount: 100,
        units: "2.0",
        free_units: "1.0",
        paid_units: "1.0",
        free_events: "0.0",
        paid_events: "1.0",
        fixed_fee_total_amount: "200.0",
        min_max_adjustment_total_amount: "10.0",
        per_unit_total_amount: "100.0"
      }
      expect(amount_details_calculator.call).to eq(expected_details)
    end
  end

  context "when charge model is graduated_percentage", :premium do
    let(:charge) { create(:graduated_percentage_charge, :pay_in_advance) }
    let(:all_charges_details) do
      {
        graduated_percentage_ranges: [
          {from_value: 0, to_value: 100, flat_unit_amount: 5, rate: 0.1, units: 10, total_with_flat_amount: 100},
          {from_value: 100, to_value: 200, flat_unit_amount: 20, rate: 0.2, units: 20, total_with_flat_amount: 400}
        ]
      }
    end
    let(:charges_details_without_last_event) do
      {
        graduated_percentage_ranges: [
          {from_value: 0, to_value: 100, flat_unit_amount: 5, rate: 0.1, units: 5, total_with_flat_amount: 50},
          {from_value: 100, to_value: 200, flat_unit_amount: 10, rate: 0.2, units: 10, total_with_flat_amount: 200}
        ]
      }
    end

    it "calculates graduated percentage charge details" do
      expected_details = {
        graduated_percentage_ranges: [
          {from_value: 0, to_value: 100, flat_unit_amount: 0, rate: 0.1, units: "5.0", per_unit_total_amount: "10.0", total_with_flat_amount: 50},
          {from_value: 100, to_value: 200, flat_unit_amount: 10, rate: 0.2, units: "10.0", per_unit_total_amount: "20.0", total_with_flat_amount: 200}
        ]
      }
      expect(amount_details_calculator.call).to eq(expected_details)
    end

    context "when first event covers all tiers" do
      let(:all_charges_details) do
        {
          graduated_percentage_ranges: [
            {from_value: 0, to_value: 100, flat_unit_amount: 10, rate: 0.1, units: 10, total_with_flat_amount: 100},
            {from_value: 100, to_value: 200, flat_unit_amount: 20, rate: 0.2, units: 20, total_with_flat_amount: 400}
          ]
        }
      end
      let(:charges_details_without_last_event) do
        {
          graduated_percentage_ranges: [
            {from_value: 0, to_value: 100, flat_unit_amount: 0, rate: 0.1, units: 0, total_with_flat_amount: 0}
          ]
        }
      end

      it "calculates graduated percentage charge details" do
        expected_details = {
          graduated_percentage_ranges: [
            {from_value: 0, to_value: 100, flat_unit_amount: 10, rate: 0.1, units: "10.0", per_unit_total_amount: "10.0", total_with_flat_amount: 100},
            {from_value: 100, to_value: 200, flat_unit_amount: 20, rate: 0.2, units: "20.0", per_unit_total_amount: "20.0", total_with_flat_amount: 400}
          ]
        }
        expect(amount_details_calculator.call).to eq(expected_details)
      end
    end
  end
end
