# frozen_string_literal: true

require "rails_helper"

RSpec.describe BillableMetrics::AggregationFactory do
  subject(:factory) { described_class }

  let(:billable_metric) { create(billable_aggregation, recurring:) }
  let(:billable_aggregation) { :billable_metric }
  let(:recurring) { false }

  let(:charge) { build(:standard_charge, billable_metric:, pay_in_advance:, prorated:) }
  let(:pay_in_advance) { false }
  let(:prorated) { false }

  let(:subscription) { create(:subscription, started_at: DateTime.parse("2023-03-15")) }
  let(:boundaries) do
    {
      charges_from_datetime: subscription.started_at.beginning_of_day,
      charges_to_datetime: subscription.started_at.end_of_month.end_of_day
    }
  end

  let(:current_usage) { false }

  let(:result) { factory.new_instance(charge:, current_usage:, subscription:, boundaries:) }

  describe "#new_instance" do
    context "with count_agg aggregation" do
      let(:billable_aggregation) { :billable_metric }

      it { expect(result).to be_a(BillableMetrics::Aggregations::CountService) }
    end

    context "with latest_agg aggregation" do
      let(:billable_aggregation) { :latest_billable_metric }

      it { expect(result).to be_a(BillableMetrics::Aggregations::LatestService) }

      context "when pay_in_advance" do
        let(:pay_in_advance) { true }

        it { expect { result }.to raise_error(NotImplementedError) }

        context "when current usage" do
          let(:current_usage) { true }

          it { expect(result).to be_a(BillableMetrics::Aggregations::LatestService) }
        end
      end
    end

    context "with max_agg aggregation" do
      let(:billable_aggregation) { :max_billable_metric }

      it { expect(result).to be_a(BillableMetrics::Aggregations::MaxService) }

      context "when pay_in_advance" do
        let(:pay_in_advance) { true }

        it { expect { result }.to raise_error(NotImplementedError) }

        context "when current usage" do
          let(:current_usage) { true }

          it { expect(result).to be_a(BillableMetrics::Aggregations::MaxService) }
        end
      end
    end

    context "with sum_agg aggregation" do
      let(:billable_aggregation) { :sum_billable_metric }

      it { expect(result).to be_a(BillableMetrics::Aggregations::SumService) }

      context "when prorated" do
        let(:prorated) { true }
        let(:recurring) { true }

        it { expect(result).to be_a(BillableMetrics::ProratedAggregations::SumService) }
      end
    end

    context "with unique_count_agg aggregation" do
      let(:billable_aggregation) { :unique_count_billable_metric }

      it { expect(result).to be_a(BillableMetrics::Aggregations::UniqueCountService) }

      context "when prorated" do
        let(:prorated) { true }
        let(:recurring) { true }

        it { expect(result).to be_a(BillableMetrics::ProratedAggregations::UniqueCountService) }
      end
    end

    context "with weighted_sum_agg aggregation" do
      let(:billable_aggregation) { :weighted_sum_billable_metric }

      it { expect(result).to be_a(BillableMetrics::Aggregations::WeightedSumService) }

      context "when pay_in_advance" do
        let(:pay_in_advance) { true }

        it { expect { result }.to raise_error(NotImplementedError) }

        context "when current usage" do
          let(:current_usage) { true }

          it { expect(result).to be_a(BillableMetrics::Aggregations::WeightedSumService) }
        end
      end
    end

    context "with custom_agg aggregation" do
      let(:billable_aggregation) { :custom_billable_metric }

      it { expect(result).to be_a(BillableMetrics::Aggregations::CustomService) }
    end
  end
end
