# frozen_string_literal: true

require "rails_helper"

RSpec.describe BillableMetrics::UpdateService do
  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }

  let(:billable_metric) { create(:billable_metric, organization:) }
  let(:params) do
    {
      name: "New Metric",
      code: "new_metric",
      description: "New metric description",
      aggregation_type: "sum_agg",
      field_name: "field_value",
      expression: "1 + 3",
      rounding_function: "ceil",
      rounding_precision: 2
    }.tap do |p|
      p[:filters] = filters unless filters.nil?
    end
  end
  let(:filters) { nil }

  describe ".call" do
    it "updates the billable metric" do
      result = described_class.call(billable_metric:, params:)
      expect(result).to be_success

      metric = result.billable_metric
      expect(metric).to have_attributes(
        id: billable_metric.id,
        name: "New Metric",
        code: "new_metric",
        aggregation_type: "sum_agg",
        rounding_function: "ceil",
        rounding_precision: 2,
        expression: "1 + 3"
      )
    end

    it "produces an activity log" do
      described_class.call(billable_metric:, params:)

      expect(Utils::ActivityLog).to have_produced("billable_metric.updated").after_commit.with(billable_metric)
    end

    it "enqueues a billable_metric.updated webhook" do
      expect { described_class.call(billable_metric:, params:) }.to have_enqueued_job_after_commit(SendWebhookJob)
        .with("billable_metric.updated", billable_metric)
    end

    it "uses with_lock to prevent race conditions" do
      allow(billable_metric).to receive(:with_lock).and_call_original
      described_class.call(billable_metric:, params:)

      expect(billable_metric).to have_received(:with_lock)
    end

    context "with filters arguments" do
      let(:filters) do
        [
          {
            key: "cloud",
            values: %w[aws google]
          }
        ]
      end

      it "updates billable metric's filters" do
        expect { described_class.call(billable_metric:, params:) }.to change { billable_metric.filters.reload.count }.from(0).to(1)
      end
    end

    context "with validation errors" do
      let(:params) do
        {
          name: nil,
          code: "new_metric",
          description: "New metric description",
          aggregation_type: "count_agg"
        }
      end

      it "returns an error" do
        result = described_class.call(billable_metric:, params:)

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages[:name]).to eq(["value_is_mandatory"])
      end
    end

    context "when the filters change but a metric attribute is invalid" do
      let(:existing_filter) { create(:billable_metric_filter, billable_metric:, key: "region", values: %w[US EU]) }
      let(:params) { {name: nil, filters: [{key: "region", values: %w[US]}]} }

      before { existing_filter }

      it "rolls back the filter changes" do
        result = described_class.call(billable_metric:, params:)

        expect(result).not_to be_success
        expect(existing_filter.reload.values).to eq(%w[US EU])
      end

      it "does not enqueue the refresh draft invoices job" do
        described_class.call(billable_metric:, params:)

        expect(BillableMetricFilters::RefreshDraftInvoicesJob).not_to have_been_enqueued
      end
    end

    context "when billable metric is not found" do
      let(:billable_metric) { nil }

      it "returns an error" do
        result = described_class.call(billable_metric:, params:)

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::NotFoundFailure)
        expect(result.error.error_code).to eq("billable_metric_not_found")
      end
    end

    context "with custom aggregation" do
      let(:params) { {aggregation_type: "custom_agg"} }

      it "returns a forbidden failure" do
        result = described_class.call(billable_metric:, params:)

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ForbiddenFailure)
      end
    end

    context "when billable metric is linked to plan" do
      let(:plan) { create(:plan, organization:) }
      let(:charge) { create(:standard_charge, billable_metric:, plan:) }

      before { charge }

      it "updates only name and description" do
        result = described_class.call(billable_metric:, params:)

        expect(result).to be_success

        expect(result.billable_metric).to have_attributes(
          name: "New Metric",
          description: "New metric description"
        )

        expect(result.billable_metric).not_to have_attributes(
          code: "new_metric",
          aggregation_type: "sum_agg",
          field_name: "field_value",
          rounding_function: "ceil",
          rounding_precision: 2
        )
      end
    end

    context "with two threads racing on the same invoice", transaction: false do
      let(:params) { {filters: [{key: "region", values: %w[US]}]} }

      before do
        allow(billable_metric).to receive(:save!).and_wrap_original do |original, *args|
          sleep(0.05)
          original.call(*args)
        end
      end

      it "serializes the requests and creates the filter exactly once" do
        results = Concurrent::Array.new

        threads = Array.new(2) do
          Thread.new do
            results << described_class.call(billable_metric:, params:)
          end
        end

        threads.each(&:join)

        expect(results.count(&:success?)).to eq(2)
        expect(billable_metric.filters.where(key: "region").count).to eq(1)
      end
    end
  end
end
