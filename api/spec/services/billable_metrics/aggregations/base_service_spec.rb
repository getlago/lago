# frozen_string_literal: true

require "rails_helper"

RSpec.describe BillableMetrics::Aggregations::BaseService do
  describe ".null_result" do
    subject(:null_result) { described_class.null_result(result, **args) }

    let(:result) { BaseService::Result.new }
    let(:args) { {} }

    context "without keyword arguments" do
      it "returns a result with zero values" do
        expect(null_result.aggregation).to eq(0)
        expect(null_result.count).to eq(0)
        expect(null_result.current_usage_units).to eq(0)
        expect(null_result.options).to eq({running_total: []})
        expect(null_result.grouped_by).to be_nil
      end

      it "populates and returns the provided result" do
        expect(null_result).to be(result)
      end
    end

    context "with grouped_by_keys" do
      let(:args) { {grouped_by_keys: %w[region plan]} }

      it "sets grouped_by with nil values for each key" do
        expect(null_result.grouped_by).to eq({"region" => nil, "plan" => nil})
        expect(null_result.aggregation).to eq(0)
        expect(null_result.count).to eq(0)
        expect(null_result.current_usage_units).to eq(0)
        expect(null_result.options).to eq({running_total: []})
      end
    end

    context "with empty grouped_by_keys" do
      let(:args) { {grouped_by_keys: []} }

      it "sets grouped_by to an empty hash" do
        expect(null_result.grouped_by).to eq({})
        expect(null_result.aggregation).to eq(0)
        expect(null_result.count).to eq(0)
      end
    end

    context "with apply_aggregation and grouped_by_keys" do
      let(:args) { {grouped_by_keys: %w[region], apply_aggregation: true} }

      it "wraps a null result inside aggregations" do
        expect(null_result.aggregations.size).to eq(1)

        inner = null_result.aggregations.first
        expect(inner.grouped_by).to eq({"region" => nil})
        expect(inner.aggregation).to eq(0)
        expect(inner.count).to eq(0)
        expect(inner.current_usage_units).to eq(0)
        expect(inner.options).to eq({running_total: []})
      end
    end

    context "with apply_aggregation and no grouped_by_keys" do
      let(:args) { {apply_aggregation: true} }

      it "returns a flat null result without aggregations wrapper" do
        expect(null_result.aggregation).to eq(0)
        expect(null_result.count).to eq(0)
        expect(null_result.current_usage_units).to eq(0)
        expect(null_result.options).to eq({running_total: []})
        expect(null_result.grouped_by).to be_nil
      end
    end
  end

  describe "#empty_results" do
    subject(:empty_results) { aggregator.empty_results }

    let(:aggregator) do
      described_class.new(
        event_store_class: Events::Stores::PostgresStore,
        charge:,
        subscription:,
        boundaries: {from_datetime: Time.current, to_datetime: Time.current},
        filters:
      )
    end

    let(:subscription) { create(:subscription) }
    let(:charge) { create(:standard_charge, plan: subscription.plan) }
    let(:filters) { {} }

    context "without grouped_by" do
      it "returns the aggregator's result zeroed out with the aggregator attached" do
        expect(empty_results.aggregator).to be(aggregator)
        expect(empty_results.aggregation).to eq(0)
        expect(empty_results.count).to eq(0)
        expect(empty_results.current_usage_units).to eq(0)
        expect(empty_results.options).to eq({running_total: []})
      end
    end

    context "with grouped_by in the filters" do
      let(:filters) { {grouped_by: %w[region provider]} }

      it "wraps a null result inside aggregations for each group key and keeps the aggregator on the outer result" do
        expect(empty_results.aggregator).to be(aggregator)
        expect(empty_results.aggregations.size).to eq(1)

        inner = empty_results.aggregations.first
        expect(inner.grouped_by).to eq({"region" => nil, "provider" => nil})
        expect(inner.aggregation).to eq(0)
        expect(inner.count).to eq(0)
        expect(inner.current_usage_units).to eq(0)
        expect(inner.options).to eq({running_total: []})
      end
    end
  end
end
