# frozen_string_literal: true

require "rails_helper"

RSpec.describe ChargeModels::GroupedService do
  subject(:apply_grouped_service) do
    described_class.apply(
      charge_model:,
      charge:,
      aggregation_result:,
      properties: charge.properties,
      period_ratio: 1.0
    )
  end

  context "with standard charge model" do
    let(:charge_model) { ChargeModels::StandardService }

    let(:aggregation_result) do
      BaseService::Result.new.tap do |result|
        result.aggregations = group_results.map do |group_result|
          BaseService::Result.new.tap do |aggregation|
            aggregation.aggregation = group_result[:aggregation]
            aggregation.count = group_result[:count]
            aggregation.grouped_by = group_result[:grouped_by]
          end
        end
      end
    end

    let(:group_results) do
      [
        {
          grouped_by: {"cloud" => "aws"},
          aggregation: 10,
          count: 2
        },
        {
          grouped_by: {"cloud" => "gcp"},
          aggregation: 20,
          count: 7
        }
      ]
    end

    let(:charge) do
      create(
        :standard_charge,
        charge_model: "standard",
        properties: {
          amount: "5.12345"
        }
      )
    end

    it "applies the charge model to the values" do
      expect(apply_grouped_service.grouped_results.count).to eq(group_results.count)

      group_results.each_with_index do |group_result, index|
        result = apply_grouped_service.grouped_results[index]

        expect(result.units).to eq(group_result[:aggregation])
        expect(result.current_usage_units).to eq(nil)
        expect(result.full_units_number).to eq(nil)
        expect(result.count).to eq(group_result[:count])
        expect(result.amount).to eq(group_result[:aggregation] * BigDecimal("5.12345"))
        expect(result.unit_amount).to eq(5.12345)
        expect(result.amount_details).to eq({})
        expect(result.grouped_by).to eq(group_result[:grouped_by])
      end
    end
  end

  context "with dynamic charge model" do
    let(:charge_model) { ChargeModels::DynamicService }
    let(:charge) { create(:dynamic_charge) }

    let(:aggregation_result) do
      BaseService::Result.new.tap do |result|
        result.aggregations = group_results.map do |group_result|
          BaseService::Result.new.tap do |aggregation|
            aggregation.aggregation = group_result[:aggregation]
            aggregation.precise_total_amount_cents = group_result[:precise_total_amount_cents]
            aggregation.count = group_result[:count]
            aggregation.grouped_by = group_result[:grouped_by]
          end
        end
      end
    end

    let(:group_results) do
      [
        {
          grouped_by: {"cloud" => "aws"},
          aggregation: 10,
          count: 2,
          precise_total_amount_cents: BigDecimal("12")
        },
        {
          grouped_by: {"cloud" => "gcp"},
          aggregation: 20,
          count: 7,
          precise_total_amount_cents: BigDecimal("9")
        }
      ]
    end

    it "applies the charge model to the values" do
      expect(apply_grouped_service.grouped_results.count).to eq(group_results.count)

      group_results.each_with_index do |group_result, index|
        result = apply_grouped_service.grouped_results[index]

        expect(result.units).to eq(group_result[:aggregation])
        expect(result.current_usage_units).to eq(nil)
        expect(result.full_units_number).to eq(nil)
        expect(result.count).to eq(group_result[:count])
        expect(result.unit_amount).to eq(group_result[:precise_total_amount_cents] / group_result[:aggregation] / 100)
        expect(result.amount_details).to eq({})
        expect(result.grouped_by).to eq(group_result[:grouped_by])
      end
    end
  end
end
