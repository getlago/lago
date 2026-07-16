# frozen_string_literal: true

require "rails_helper"

RSpec.describe Events::Stores::Clickhouse::EnrichedStoreMigration::ComparisonService do
  subject(:service) { described_class.new(subscription:, deduplicate:) }

  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:plan) { create(:plan, organization:) }
  let(:subscription) { create(:subscription, organization:, customer:, plan:) }
  let(:deduplicate) { false }

  let(:billable_metric) { create(:billable_metric, organization:, code: "api_calls", aggregation_type: "count_agg") }
  let(:charge) { create(:standard_charge, plan:, billable_metric:, organization:) }

  let(:fee_attributes) do
    {
      charge:,
      charge_filter_id: nil,
      grouped_by: {},
      properties: {"charges_from_datetime" => "2026-04-01T00:00:00Z", "charges_to_datetime" => "2026-04-30T23:59:59Z"}
    }
  end

  describe "#call" do
    let(:legacy_fee) do
      Fee.new(
        fee_attributes.merge(
          units: 10,
          amount_cents: 1000,
          events_count: 5,
          total_aggregated_units: 10
        )
      )
    end

    let(:enriched_fee) do
      Fee.new(
        fee_attributes.merge(
          units: 10,
          amount_cents: 1000,
          events_count: 5,
          total_aggregated_units: 10
        )
      )
    end

    let(:legacy_usage) { SubscriptionUsage.new(fees: [legacy_fee]) }
    let(:enriched_usage) { SubscriptionUsage.new(fees: [enriched_fee]) }
    let(:legacy_result) { BaseService::LegacyResult.new.tap { |r| r.usage = legacy_usage } }
    let(:enriched_result) { BaseService::LegacyResult.new.tap { |r| r.usage = enriched_usage } }

    before do
      allow(Invoices::CustomerUsageService).to receive(:call)
        .and_return(legacy_result, enriched_result)
    end

    context "when fees match" do
      it "returns zero diffs with timing and fee metadata" do
        result = service.call

        expect(result).to be_success
        expect(result.diff_count).to eq(0)
        expect(result.legacy_elapsed).to be_a(Float)
        expect(result.enriched_elapsed).to be_a(Float)

        detail = result.fee_details.first
        expect(detail).to be_a(described_class::FeeDetail)
        expect(detail.status).to eq("match")
        expect(detail.billable_metric_code).to eq("api_calls")
        expect(detail.aggregation_type).to eq("count_agg")
        expect(detail.charge_model).to eq("standard")
        expect(detail.from).to eq("2026-04-01T00:00:00Z")
        expect(detail.to).to eq("2026-04-30T23:59:59Z")
      end
    end

    context "when fees have differences" do
      let(:enriched_fee) do
        Fee.new(
          fee_attributes.merge(
            units: 12,
            amount_cents: 1200,
            events_count: 6,
            total_aggregated_units: 12
          )
        )
      end

      it "returns the diffs" do
        result = service.call

        expect(result).to be_success
        expect(result.diff_count).to eq(1)

        detail = result.fee_details.first
        expect(detail.status).to eq("diff")
        expect(detail.diffs).to match(
          units: described_class::FieldDiff.new(legacy: 10.0, enriched: 12.0),
          amount_cents: described_class::FieldDiff.new(legacy: 1000, enriched: 1200),
          events_count: described_class::FieldDiff.new(legacy: 5, enriched: 6),
          total_aggregated_units: described_class::FieldDiff.new(legacy: 10.0, enriched: 12.0)
        )
      end
    end

    context "when a fee exists only in legacy" do
      let(:enriched_usage) { SubscriptionUsage.new(fees: []) }

      it "reports the fee as only_in_legacy" do
        result = service.call

        expect(result).to be_success
        expect(result.diff_count).to eq(1)
        expect(result.fee_details.first.status).to eq("only_in_legacy")
      end
    end

    context "when a fee exists only in enriched" do
      let(:legacy_usage) { SubscriptionUsage.new(fees: []) }

      it "reports the fee as only_in_enriched" do
        result = service.call

        expect(result).to be_success
        expect(result.diff_count).to eq(1)
        expect(result.fee_details.first.status).to eq("only_in_enriched")
      end
    end

    context "when the service completes successfully" do
      it "does not alter the organization state" do
        original_flags = organization.feature_flags.dup
        original_dedup = organization.clickhouse_deduplication_enabled
        original_pre_filter = organization.pre_filter_events

        service.call
        organization.reload

        expect(organization.feature_flags).to eq(original_flags)
        expect(organization.clickhouse_deduplication_enabled).to eq(original_dedup)
        expect(organization.pre_filter_events).to eq(original_pre_filter)
      end
    end

    context "when legacy computation fails" do
      let(:legacy_result) do
        BaseService::LegacyResult.new.tap { |r| r.service_failure!(code: "legacy_error", message: "legacy computation broke") }
      end

      it "returns the original error" do
        result = service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ServiceFailure)
        expect(result.error.code).to eq("legacy_error")
        expect(result.error.message).to include("legacy computation broke")
      end

      it "does not alter the organization state" do
        original_flags = organization.feature_flags.dup
        original_dedup = organization.clickhouse_deduplication_enabled
        original_pre_filter = organization.pre_filter_events

        service.call
        organization.reload

        expect(organization.feature_flags).to eq(original_flags)
        expect(organization.clickhouse_deduplication_enabled).to eq(original_dedup)
        expect(organization.pre_filter_events).to eq(original_pre_filter)
      end
    end

    context "when enriched computation fails" do
      let(:enriched_result) do
        BaseService::LegacyResult.new.tap { |r| r.service_failure!(code: "enriched_error", message: "enriched computation broke") }
      end

      it "returns the original error" do
        result = service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ServiceFailure)
        expect(result.error.code).to eq("enriched_error")
        expect(result.error.message).to include("enriched computation broke")
      end

      it "does not alter the organization state" do
        original_flags = organization.feature_flags.dup
        original_dedup = organization.clickhouse_deduplication_enabled
        original_pre_filter = organization.pre_filter_events

        service.call
        organization.reload

        expect(organization.feature_flags).to eq(original_flags)
        expect(organization.clickhouse_deduplication_enabled).to eq(original_dedup)
        expect(organization.pre_filter_events).to eq(original_pre_filter)
      end
    end
  end
end
