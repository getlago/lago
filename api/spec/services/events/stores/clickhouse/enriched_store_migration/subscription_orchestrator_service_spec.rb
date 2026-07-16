# frozen_string_literal: true

require "rails_helper"

RSpec.describe Events::Stores::Clickhouse::EnrichedStoreMigration::SubscriptionOrchestratorService do
  subject(:service) { described_class.new(subscription_migration:) }

  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:plan) { create(:plan, organization:) }
  let(:subscription) { create(:subscription, organization:, customer:, plan:) }
  let(:migration) { create(:enriched_store_migration, :processing, organization:) }

  let(:comparison_service) { Events::Stores::Clickhouse::EnrichedStoreMigration::ComparisonService }

  let(:comparison_result) do
    result = comparison_service::Result.new
    result.diff_count = diff_count
    result.fee_details = fee_details
    result
  end

  let(:diff_count) { 0 }
  let(:fee_details) { [] }

  before do
    allow(comparison_service).to receive(:call).and_return(comparison_result)
    allow(Events::Stores::Clickhouse::EnrichedStoreMigration::OrchestratorJob)
      .to receive(:perform_later)
  end

  describe "#call" do
    context "when pending with no diffs" do
      let(:subscription_migration) do
        create(:enriched_store_subscription_migration,
          enriched_store_migration: migration,
          organization:,
          subscription:)
      end

      it "transitions to completed via fast path" do
        service.call
        subscription_migration.reload
        expect(subscription_migration).to be_completed
        expect(Events::Stores::Clickhouse::EnrichedStoreMigration::OrchestratorJob)
          .to have_received(:perform_later).with(migration)
      end
    end

    context "when pending with diffs and codes to reprocess" do
      let(:diff_count) { 1 }
      let(:fee_details) do
        [
          comparison_service::FeeDetail.new(
            charge_id: "c1", charge_filter_id: nil, grouped_by: {},
            billable_metric_code: "api_calls", aggregation_type: "count_agg",
            charge_model: "standard", from: nil, to: nil,
            status: "diff", legacy: nil, enriched: nil, diffs: {}
          )
        ]
      end

      let(:subscription_migration) do
        create(:enriched_store_subscription_migration,
          enriched_store_migration: migration,
          organization:,
          subscription:)
      end

      let(:reprocess_result) do
        result = Events::Stores::Clickhouse::ReEnrichSubscriptionEventsService::Result.new
        result.events_count = 42
        result.batch_count = 1
        result
      end

      before do
        allow(Events::Stores::Clickhouse::ReEnrichSubscriptionEventsService)
          .to receive(:call).and_return(reprocess_result)
        allow(Events::Stores::Clickhouse::EnrichedStoreMigration::WaitForEnrichmentJob)
          .to receive(:perform_later)
      end

      it "assigns billable_metric_codes and transitions to waiting_for_enrichment" do
        service.call
        subscription_migration.reload
        expect(subscription_migration).to be_waiting_for_enrichment
        expect(subscription_migration.billable_metric_codes).to eq(["api_calls"])
        expect(subscription_migration.events_reprocessed_count).to eq(42)
        expect(Events::Stores::Clickhouse::EnrichedStoreMigration::WaitForEnrichmentJob)
          .to have_received(:perform_later).with(subscription_migration)
      end
    end

    context "when pending with diffs but no codes" do
      let(:diff_count) { 1 }
      let(:fee_details) do
        [
          comparison_service::FeeDetail.new(
            charge_id: "c1", charge_filter_id: nil, grouped_by: {},
            billable_metric_code: nil, aggregation_type: nil,
            charge_model: "standard", from: nil, to: nil,
            status: "diff", legacy: nil, enriched: nil, diffs: {}
          )
        ]
      end

      let(:subscription_migration) do
        create(:enriched_store_subscription_migration,
          enriched_store_migration: migration,
          organization:,
          subscription:)
      end

      it "transitions to failed" do
        service.call
        subscription_migration.reload
        expect(subscription_migration).to be_failed
        expect(subscription_migration.error_message).to include("no billable metric codes")
      end
    end

    context "when deduplicating successfully" do
      let(:billable_metric_codes) { ["code1"] }

      let(:subscription_migration) do
        create(:enriched_store_subscription_migration, :deduplicating,
          enriched_store_migration: migration,
          organization:,
          subscription:,
          billable_metric_codes:)
      end

      let(:dedup_result) do
        result = Events::Stores::Clickhouse::CleanDuplicatedEnrichedExpandedService::Result.new
        result.duplicated_count = 5
        result.queries = []
        result
      end

      before do
        allow(Events::Stores::Clickhouse::CleanDuplicatedEnrichedExpandedService)
          .to receive(:call).and_return(dedup_result)
      end

      it "transitions to completed after validating" do
        service.call
        subscription_migration.reload
        expect(subscription_migration).to be_completed
        expect(subscription_migration.duplicates_removed_count).to eq(5)
      end
    end

    context "when deduplicating with timeout" do
      let(:billable_metric_codes) { ["code1"] }

      let(:subscription_migration) do
        create(:enriched_store_subscription_migration, :deduplicating,
          enriched_store_migration: migration,
          organization:,
          subscription:,
          billable_metric_codes:)
      end

      let(:dedup_result) do
        result = Events::Stores::Clickhouse::CleanDuplicatedEnrichedExpandedService::Result.new
        result.duplicated_count = 100
        result.queries = ["DELETE FROM events_enriched_expanded WHERE ..."]
        result
      end

      before do
        allow(Events::Stores::Clickhouse::CleanDuplicatedEnrichedExpandedService)
          .to receive(:call).and_return(dedup_result)
      end

      it "transitions to dedup_paused with pending queries" do
        service.call
        subscription_migration.reload
        expect(subscription_migration).to be_dedup_paused
        expect(subscription_migration.dedup_pending_queries).to eq(["DELETE FROM events_enriched_expanded WHERE ..."])
      end
    end

    context "when deduplicating with failure" do
      let(:subscription_migration) do
        create(:enriched_store_subscription_migration, :deduplicating,
          enriched_store_migration: migration,
          organization:,
          subscription:)
      end

      before do
        failed_result = Events::Stores::Clickhouse::CleanDuplicatedEnrichedExpandedService::Result.new
        failed_result.service_failure!(code: :dedup_failure, message: "Deduplication failed")
        allow(Events::Stores::Clickhouse::CleanDuplicatedEnrichedExpandedService).to receive(:call).and_return(failed_result)
      end

      it "transitions to failed" do
        service.call
        subscription_migration.reload
        expect(subscription_migration).to be_failed
        expect(subscription_migration.error_message).to eq("dedup_failure: Deduplication failed")
      end
    end

    context "when validating with no diffs" do
      let(:subscription_migration) do
        create(:enriched_store_subscription_migration, :validating,
          enriched_store_migration: migration,
          organization:,
          subscription:)
      end

      it "transitions to completed" do
        service.call
        subscription_migration.reload
        expect(subscription_migration).to be_completed
        expect(Events::Stores::Clickhouse::EnrichedStoreMigration::OrchestratorJob)
          .to have_received(:perform_later).with(migration)
      end
    end

    context "when validating with diffs" do
      let(:diff_count) { 2 }
      let(:fee_details) do
        [
          comparison_service::FeeDetail.new(
            charge_id: "c1", charge_filter_id: nil, grouped_by: {},
            billable_metric_code: "api_calls", aggregation_type: "count_agg",
            charge_model: "standard", from: nil, to: nil,
            status: "diff", legacy: nil, enriched: nil, diffs: {}
          ),
          comparison_service::FeeDetail.new(
            charge_id: "c2", charge_filter_id: nil, grouped_by: {},
            billable_metric_code: "storage", aggregation_type: "sum_agg",
            charge_model: "standard", from: nil, to: nil,
            status: "diff", legacy: nil, enriched: nil, diffs: {}
          )
        ]
      end

      let(:subscription_migration) do
        create(:enriched_store_subscription_migration, :validating,
          enriched_store_migration: migration,
          organization:,
          subscription:)
      end

      it "transitions to failed" do
        service.call
        subscription_migration.reload
        expect(subscription_migration).to be_failed
        expect(subscription_migration.error_message).to include("2 diff(s) remain")
      end
    end

    context "when comparison service fails" do
      let(:subscription_migration) do
        create(:enriched_store_subscription_migration,
          enriched_store_migration: migration,
          organization:,
          subscription:)
      end

      before do
        failed_result = comparison_service::Result.new
        failed_result.service_failure!(code: "error", message: "something broke")
        allow(comparison_service).to receive(:call).and_return(failed_result)
      end

      it "transitions to failed" do
        service.call
        subscription_migration.reload
        expect(subscription_migration).to be_failed
        expect(subscription_migration.error_message).to include("something broke")
      end
    end

    context "when in an unactionable state" do
      let(:subscription_migration) do
        create(:enriched_store_subscription_migration, :waiting_for_enrichment,
          enriched_store_migration: migration,
          organization:,
          subscription:)
      end

      it "returns a failed result" do
        result = service.call
        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ServiceFailure)
        expect(result.error.code.to_s).to eq("invalid_status")
        expect(result.error.error_message).to eq("Unprocessable status: waiting_for_enrichment")
      end
    end
  end
end
