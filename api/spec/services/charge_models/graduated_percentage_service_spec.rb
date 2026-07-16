# frozen_string_literal: true

require "rails_helper"

RSpec.describe ChargeModels::GraduatedPercentageService, :premium do
  subject(:apply_graduated_percentage_service) do
    described_class.apply(
      charge:,
      aggregation_result:,
      properties: charge.properties,
      period_ratio: 1.0
    )
  end

  let(:aggregation_result) do
    BaseService::Result.new.tap do |r|
      r.aggregation = aggregation
      r.count = aggregation_count
    end
  end

  let(:charge) do
    create(
      :graduated_percentage_charge,
      properties: {
        graduated_percentage_ranges: [
          {
            from_value: 0,
            to_value: 10,
            flat_amount: "200",
            rate: "1"
          },
          {
            from_value: 11,
            to_value: 20,
            flat_amount: "300",
            rate: "2"
          },
          {
            from_value: 21,
            to_value: nil,
            flat_amount: "400",
            rate: "3"
          }
        ]
      }
    )
  end

  context "when aggregation is 0" do
    let(:aggregation) { 0 }
    let(:aggregation_count) { 0 }

    it "does not apply the flat amount" do
      expect(apply_graduated_percentage_service.amount).to eq(0)
      expect(apply_graduated_percentage_service.unit_amount).to eq(0)
      expect(apply_graduated_percentage_service.amount_details).to eq(
        {
          graduated_percentage_ranges: [
            {
              flat_unit_amount: 0,
              from_value: 0,
              to_value: 10,
              per_unit_total_amount: "0.0",
              total_with_flat_amount: 0,
              rate: 1.0,
              units: "0.0"
            }
          ]
        }
      )
    end
  end

  context "when aggregation is 1" do
    let(:aggregation) { 1 }
    let(:aggregation_count) { 1 }

    it "applies a unit amount for 1 and the flat rate for 1" do
      # NOTE: 200 + 1 * 0.01
      expect(apply_graduated_percentage_service.amount).to eq(200.01)
      expect(apply_graduated_percentage_service.unit_amount).to eq(200.01)
      expect(apply_graduated_percentage_service.amount_details).to eq(
        {
          graduated_percentage_ranges: [
            {
              flat_unit_amount: 200,
              from_value: 0,
              to_value: 10,
              per_unit_total_amount: "0.01",
              total_with_flat_amount: 200.01,
              rate: 1.0,
              units: "1.0"
            }
          ]
        }
      )
    end
  end

  context "when aggregation is 10" do
    let(:aggregation) { 10 }
    let(:aggregation_count) { 1 }

    it "applies all unit amount up to the top bound" do
      # NOTE: 200 + 10 * 0.01
      expect(apply_graduated_percentage_service.amount).to eq(200.1)
      expect(apply_graduated_percentage_service.unit_amount).to eq(20.01)
      expect(apply_graduated_percentage_service.amount_details).to eq(
        {
          graduated_percentage_ranges: [
            {
              flat_unit_amount: 200,
              from_value: 0,
              to_value: 10,
              per_unit_total_amount: "0.1",
              total_with_flat_amount: 200.1,
              rate: 1.0,
              units: "10.0"
            }
          ]
        }
      )
    end
  end

  context "when aggregation is 11" do
    let(:aggregation) { 11 }
    let(:aggregation_count) { 1 }

    it "applies next ranges flat amount" do
      # NOTE: 200 + 300 + 10 * 0.01 + 1 * 0.02
      expect(apply_graduated_percentage_service.amount).to eq(500.12)
      expect(apply_graduated_percentage_service.unit_amount.round(2)).to eq(45.47)
      expect(apply_graduated_percentage_service.amount_details).to eq(
        {
          graduated_percentage_ranges: [
            {
              flat_unit_amount: 200,
              from_value: 0,
              to_value: 10,
              per_unit_total_amount: "0.1",
              total_with_flat_amount: 200.1,
              rate: 1.0,
              units: "10.0"
            },
            {
              flat_unit_amount: 300,
              from_value: 11,
              to_value: 20,
              per_unit_total_amount: "0.02",
              total_with_flat_amount: 300.02,
              rate: 2.0,
              units: "1.0"
            }
          ]
        }
      )
    end
  end

  context "when aggregation is 12" do
    let(:aggregation) { 12 }
    let(:aggregation_count) { 1 }

    it "applies next ranges flat amount and range units amount" do
      # NOTE: 200 + 300 + 10 * 0.01 + 2 * 0.02
      expect(apply_graduated_percentage_service.amount).to eq(500.14)
      expect(apply_graduated_percentage_service.unit_amount.round(2)).to eq(41.68)
      expect(apply_graduated_percentage_service.amount_details).to eq(
        {
          graduated_percentage_ranges: [
            {
              flat_unit_amount: 200,
              from_value: 0,
              to_value: 10,
              per_unit_total_amount: "0.1",
              total_with_flat_amount: 200.1,
              rate: 1.0,
              units: "10.0"
            },
            {
              flat_unit_amount: 300,
              from_value: 11,
              to_value: 20,
              per_unit_total_amount: "0.04",
              total_with_flat_amount: 300.04,
              rate: 2.0,
              units: "2.0"
            }
          ]
        }
      )
    end
  end

  context "when aggregation is 21" do
    let(:aggregation) { 21 }
    let(:aggregation_count) { 1 }

    it "applies last unit amount for more unit in last step" do
      # NOTE: 200 + 300 + 400 + 10 * 0.01 + 10 * 0.02 + 1 * 0.03
      expect(apply_graduated_percentage_service.amount).to eq(900.33)
      expect(apply_graduated_percentage_service.unit_amount.round(2)).to eq(42.87)
      expect(apply_graduated_percentage_service.amount_details).to eq(
        {
          graduated_percentage_ranges: [
            {
              flat_unit_amount: 200,
              from_value: 0,
              to_value: 10,
              per_unit_total_amount: "0.1",
              total_with_flat_amount: 200.1,
              rate: 1.0,
              units: "10.0"
            },
            {
              flat_unit_amount: 300,
              from_value: 11,
              to_value: 20,
              per_unit_total_amount: "0.2",
              total_with_flat_amount: 300.2,
              rate: 2.0,
              units: "10.0"
            },
            {
              flat_unit_amount: 400,
              from_value: 21,
              to_value: nil,
              per_unit_total_amount: "0.03",
              total_with_flat_amount: 400.03,
              rate: 3.0,
              units: "1.0"
            }
          ]
        }
      )
    end
  end
end
