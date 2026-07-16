# frozen_string_literal: true

require "rails_helper"

RSpec.describe ChargeModels::VolumeService do
  subject(:apply_volume_service) do
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
      :volume_charge,
      properties: {
        volume_ranges: [
          {from_value: 0, to_value: 100, per_unit_amount: "2", flat_amount: "10"},
          {from_value: 101, to_value: 200, per_unit_amount: "1", flat_amount: "0"},
          {from_value: 201, to_value: nil, per_unit_amount: "0.5", flat_amount: "50"}
        ]
      }
    )
  end

  context "when aggregation is 0" do
    let(:aggregation) { 0 }

    it "does not apply the flat amount" do
      expect(apply_volume_service.amount).to eq(0)
      expect(apply_volume_service.unit_amount).to eq(0)
      expect(apply_volume_service.amount_details).to eq(
        {
          flat_unit_amount: 0.0,
          per_unit_amount: 0.0,
          per_unit_total_amount: 0.0
        }
      )
    end
  end

  context "when aggregation is 1" do
    let(:aggregation) { 1 }

    it "applies a unit amount for 1 and the flat amount" do
      expect(apply_volume_service.amount).to eq(12)
      expect(apply_volume_service.unit_amount).to eq(12)
      expect(apply_volume_service.amount_details).to eq(
        {
          flat_unit_amount: 10,
          per_unit_amount: "2.0",
          per_unit_total_amount: 2
        }
      )
    end
  end

  context "when aggregation is the limit of the first range" do
    let(:aggregation) { 100 }

    it "applies unit amount for the first range and the flat amount" do
      expect(apply_volume_service.amount).to eq(210)
      expect(apply_volume_service.unit_amount).to eq(2.1)
      expect(apply_volume_service.amount_details).to eq(
        {
          flat_unit_amount: 10,
          per_unit_amount: "2.0",
          per_unit_total_amount: 200
        }
      )
    end
  end

  context "when aggregation is in the between of first and second range" do
    let(:aggregation) { 100.5 }

    it "applies unit amount for the second range and no flat amount" do
      expect(apply_volume_service.amount).to eq(100.5)
      expect(apply_volume_service.unit_amount).to eq(1)
      expect(apply_volume_service.amount_details).to eq(
        {
          flat_unit_amount: 0,
          per_unit_amount: "1.0",
          per_unit_total_amount: 100.5
        }
      )
    end
  end

  context "when aggregation is the lower limit of the second range" do
    let(:aggregation) { 101 }

    it "applies unit amount the second range and no flat amount" do
      expect(apply_volume_service.amount).to eq(101)
      expect(apply_volume_service.unit_amount).to eq(1)
      expect(apply_volume_service.amount_details).to eq(
        {
          flat_unit_amount: 0,
          per_unit_amount: "1.0",
          per_unit_total_amount: 101
        }
      )
    end
  end

  context "when aggregation is the uper limit of the second range" do
    let(:aggregation) { 200 }

    it "applies unit amount the second range and no flat amount" do
      expect(apply_volume_service.amount).to eq(200)
      expect(apply_volume_service.unit_amount).to eq(1)
      expect(apply_volume_service.amount_details).to eq(
        {
          flat_unit_amount: 0,
          per_unit_amount: "1.0",
          per_unit_total_amount: 200
        }
      )
    end
  end

  context "when aggregation is the above the lower limit of the last range" do
    let(:aggregation) { 300 }

    it "applies unit amount the second range and no flat amount" do
      expect(apply_volume_service.amount).to eq(200)
      expect(apply_volume_service.unit_amount.round(2)).to eq(0.67)
      expect(apply_volume_service.amount_details).to eq(
        {
          flat_unit_amount: 50,
          per_unit_amount: "0.5",
          per_unit_total_amount: 150
        }
      )
    end
  end

  context "when charge is prorated" do
    let(:aggregation) { 198.6 }
    let(:billable_metric) { create(:sum_billable_metric, recurring: true) }

    before do
      charge.update!(prorated: true, billable_metric:)
      aggregation_result.full_units_number = 300
    end

    it "applies unit amount the third range" do
      expect(apply_volume_service.amount).to eq(149.3)
      expect(apply_volume_service.unit_amount.round(2)).to eq(0.50)
      expect(apply_volume_service.amount_details).to eq(
        {
          flat_unit_amount: 50,
          per_unit_amount: "0.331",
          per_unit_total_amount: 99.3
        }
      )
    end
  end

  context "when charge is a fixed charge" do
    let(:aggregation) { 210 }
    let(:charge) do
      build(
        :fixed_charge,
        charge_model: :volume,
        properties: {
          volume_ranges: [
            {from_value: 0, to_value: 100, per_unit_amount: "2", flat_amount: "10"},
            {from_value: 101, to_value: 200, per_unit_amount: "1", flat_amount: "0"},
            {from_value: 201, to_value: nil, per_unit_amount: "0.5", flat_amount: "50"}
          ]
        }
      )
    end

    it "applies the charge model to the value" do
      # 50 + 210 * 0.5 = 155
      expect(apply_volume_service.amount).to eq(155)
      expect(apply_volume_service.unit_amount.round(2)).to eq((155 / 210.0).round(2))
    end
  end
end
