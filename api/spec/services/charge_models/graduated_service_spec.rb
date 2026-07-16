# frozen_string_literal: true

require "rails_helper"

RSpec.describe ChargeModels::GraduatedService do
  subject(:apply_graduated_service) do
    described_class.apply(
      charge:,
      aggregation_result:,
      properties: charge.properties,
      period_ratio: 1.0
    )
  end

  before do
    aggregation_result.aggregation = aggregation
  end

  let(:aggregation_result) { BaseService::Result.new }

  let(:charge) do
    create(
      :graduated_charge,
      properties: {
        graduated_ranges: [
          {
            from_value: 0,
            to_value: 10,
            per_unit_amount: "10",
            flat_amount: "2"
          },
          {
            from_value: 11,
            to_value: 20,
            per_unit_amount: "5",
            flat_amount: "3"
          },
          {
            from_value: 21,
            to_value: nil,
            per_unit_amount: "5",
            flat_amount: "3"
          }
        ]
      }
    )
  end

  context "when aggregation is 0" do
    let(:aggregation) { 0 }

    it "returns expected amount" do
      expect(apply_graduated_service.amount).to eq(0)
      expect(apply_graduated_service.unit_amount).to eq(0)
      expect(apply_graduated_service.amount_details).to eq(
        {
          graduated_ranges: [
            {
              flat_unit_amount: 0,
              from_value: 0,
              to_value: 10,
              per_unit_total_amount: 0,
              total_with_flat_amount: 0,
              per_unit_amount: 0,
              units: "0.0"
            }
          ]
        }
      )
    end
  end

  context "when aggregation is 1" do
    let(:aggregation) { 1 }

    it "returns expected amount" do
      expect(apply_graduated_service.amount).to eq(12)
      expect(apply_graduated_service.unit_amount).to eq(12)
      expect(apply_graduated_service.amount_details).to eq(
        {
          graduated_ranges: [
            {
              flat_unit_amount: 2,
              from_value: 0,
              to_value: 10,
              per_unit_total_amount: 10,
              total_with_flat_amount: 12,
              per_unit_amount: 10,
              units: "1.0"
            }
          ]
        }
      )
    end
  end

  context "when aggregation is 10" do
    let(:aggregation) { 10 }

    it "returns expected amount" do
      expect(apply_graduated_service.amount).to eq(102)
      expect(apply_graduated_service.unit_amount).to eq(10.2)
      expect(apply_graduated_service.amount_details).to eq(
        {
          graduated_ranges: [
            {
              flat_unit_amount: 2,
              from_value: 0,
              to_value: 10,
              per_unit_total_amount: 100,
              total_with_flat_amount: 102,
              per_unit_amount: 10,
              units: "10.0"
            }
          ]
        }
      )
    end
  end

  context "when aggregation is 11" do
    let(:aggregation) { 11 }

    it "returns expected amount" do
      expect(apply_graduated_service.amount).to eq(110)
      expect(apply_graduated_service.unit_amount).to eq(10)
      expect(apply_graduated_service.amount_details).to eq(
        {
          graduated_ranges: [
            {
              flat_unit_amount: 2,
              from_value: 0,
              to_value: 10,
              per_unit_total_amount: 100,
              total_with_flat_amount: 102,
              per_unit_amount: 10,
              units: "10.0"
            },
            {
              flat_unit_amount: 3,
              from_value: 11,
              to_value: 20,
              per_unit_total_amount: 5,
              total_with_flat_amount: 8,
              per_unit_amount: 5,
              units: "1.0"
            }
          ]
        }
      )
    end
  end

  context "when aggregation is 12" do
    let(:aggregation) { 12 }

    it "returns expected amount" do
      expect(apply_graduated_service.amount).to eq(115)
      expect(apply_graduated_service.unit_amount.round(5)).to eq(9.58333)
      expect(apply_graduated_service.amount_details).to eq(
        {
          graduated_ranges: [
            {
              flat_unit_amount: 2,
              from_value: 0,
              to_value: 10,
              per_unit_total_amount: 100,
              total_with_flat_amount: 102,
              per_unit_amount: 10,
              units: "10.0"
            },
            {
              flat_unit_amount: 3,
              from_value: 11,
              to_value: 20,
              per_unit_total_amount: 10,
              total_with_flat_amount: 13,
              per_unit_amount: 5,
              units: "2.0"
            }
          ]
        }
      )
    end
  end

  context "when aggregation is 21" do
    let(:aggregation) { 21 }

    it "returns expected amount" do
      expect(apply_graduated_service.amount).to eq(163)
      expect(apply_graduated_service.unit_amount.round(2)).to eq(7.76)
      expect(apply_graduated_service.amount_details).to eq(
        {
          graduated_ranges: [
            {
              flat_unit_amount: 2,
              from_value: 0,
              to_value: 10,
              per_unit_total_amount: 100,
              total_with_flat_amount: 102,
              per_unit_amount: 10,
              units: "10.0"
            },
            {
              flat_unit_amount: 3,
              from_value: 11,
              to_value: 20,
              per_unit_total_amount: 50,
              total_with_flat_amount: 53,
              per_unit_amount: 5,
              units: "10.0"
            },
            {
              flat_unit_amount: 3,
              from_value: 21,
              to_value: nil,
              per_unit_total_amount: 5,
              total_with_flat_amount: 8,
              per_unit_amount: 5,
              units: "1.0"
            }
          ]
        }
      )
    end
  end

  context "with decimal adjacent ranges" do
    let(:charge) do
      create(
        :graduated_charge,
        properties: {
          graduated_ranges: [
            {from_value: 0, to_value: 0.1, per_unit_amount: "10", flat_amount: "0"},
            {from_value: 0.1, to_value: 1, per_unit_amount: "5", flat_amount: "0"},
            {from_value: 1, to_value: nil, per_unit_amount: "2", flat_amount: "0"}
          ]
        }
      )
    end

    context "when aggregation is within first tier (0.05)" do
      let(:aggregation) { 0.05 }

      it "returns expected amount" do
        expect(apply_graduated_service.amount).to eq(0.5)
        expect(apply_graduated_service.amount_details).to eq(
          {
            graduated_ranges: [
              {
                flat_unit_amount: 0,
                from_value: 0,
                to_value: 0.1,
                per_unit_amount: 10,
                per_unit_total_amount: 0.5,
                total_with_flat_amount: 0.5,
                units: "0.05"
              }
            ]
          }
        )
      end
    end

    context "when aggregation spans two tiers (0.5)" do
      let(:aggregation) { 0.5 }

      it "returns expected amount" do
        # First tier: 0.1 units * 10 = 1.0
        # Second tier: 0.4 units * 5 = 2.0
        expect(apply_graduated_service.amount).to eq(3.0)
        expect(apply_graduated_service.amount_details).to eq(
          {
            graduated_ranges: [
              {
                flat_unit_amount: 0,
                from_value: 0,
                to_value: 0.1,
                per_unit_amount: 10,
                per_unit_total_amount: 1.0,
                total_with_flat_amount: 1.0,
                units: "0.1"
              },
              {
                flat_unit_amount: 0,
                from_value: 0.1,
                to_value: 1,
                per_unit_amount: 5,
                per_unit_total_amount: 2.0,
                total_with_flat_amount: 2.0,
                units: "0.4"
              }
            ]
          }
        )
      end
    end
  end

  context "when charge is a fixed charge" do
    let(:aggregation) { 21 }
    let(:charge) do
      build(:fixed_charge, charge_model: :graduated, properties: {
        graduated_ranges: [
          {from_value: 0, to_value: 10, per_unit_amount: "10", flat_amount: "2"},
          {from_value: 11, to_value: 20, per_unit_amount: "5", flat_amount: "3"},
          {from_value: 21, to_value: nil, per_unit_amount: "5", flat_amount: "3"}
        ]
      })
    end

    it "applies the charge model to the value" do
      # 2 + 100 + 3 + 50 + 3 + 5 = 163
      expect(apply_graduated_service.amount).to eq(163)
      expect(apply_graduated_service.unit_amount.round(2)).to eq((163 / 21.0).round(2))
    end
  end
end
