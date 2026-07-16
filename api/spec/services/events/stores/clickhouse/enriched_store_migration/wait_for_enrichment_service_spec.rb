# frozen_string_literal: true

require "rails_helper"

RSpec.describe Events::Stores::Clickhouse::EnrichedStoreMigration::WaitForEnrichmentService, clickhouse: {clean_before: true} do
  subject(:service) { described_class.new(subscription_migration:, attempt:, max_attempts:) }

  let(:organization) { create(:organization) }
  let(:migration) { create(:enriched_store_migration, :processing, organization:) }
  let(:plan) { create(:plan, organization:) }
  let(:billable_metric) { create(:billable_metric, organization:, code: "code1") }
  let(:charge) { create(:standard_charge, plan:, billable_metric:) }
  let(:subscription) { create(:subscription, organization:, plan:) }
  let(:subscription_migration) do
    create(:enriched_store_subscription_migration, :waiting_for_enrichment,
      enriched_store_migration: migration,
      organization:,
      subscription:,
      events_reprocessed_count:,
      billable_metric_codes: ["code1"])
  end

  let(:attempt) { 1 }
  let(:max_attempts) { 10 }
  let(:events_reprocessed_count) { 3 }

  def create_enriched_expanded_event(transaction_id: SecureRandom.uuid, event_charge: charge)
    Clickhouse::EventsEnrichedExpanded.create!(
      transaction_id:,
      organization_id: organization.id,
      external_subscription_id: subscription.external_id,
      subscription_id: subscription.id,
      plan_id: plan.id,
      code: billable_metric.code,
      aggregation_type: billable_metric.aggregation_type,
      charge_id: event_charge.id,
      charge_version: event_charge.updated_at,
      charge_filter_id: "",
      timestamp: Time.current,
      properties: {},
      grouped_by: {},
      value: "1",
      decimal_value: 1.to_d,
      precise_total_amount_cents: nil,
      enriched_at: Time.current
    )
  end

  describe "#call" do
    context "when enriched events are ready" do
      before do
        3.times { create_enriched_expanded_event }
      end

      it "transitions to deduplicating and returns ready status" do
        result = service.call

        subscription_migration.reload
        expect(result.status).to eq(:ready)
        expect(result.enriched_count).to eq(3)
        expect(subscription_migration).to be_deduplicating
        expect(subscription_migration.attempts).to eq(1)

        expect(Events::Stores::Clickhouse::EnrichedStoreMigration::SubscriptionOrchestratorJob)
          .to have_been_enqueued.with(subscription_migration)
      end
    end

    context "when a single event produces multiple enriched_expanded rows" do
      let(:charge_2) { create(:standard_charge, plan:, billable_metric:) }
      let(:events_reprocessed_count) { 1 }

      before do
        transaction_id = SecureRandom.uuid
        create_enriched_expanded_event(transaction_id:, event_charge: charge)
        create_enriched_expanded_event(transaction_id:, event_charge: charge_2)
      end

      it "counts distinct events, not total rows" do
        result = service.call

        expect(result.status).to eq(:ready)
        expect(result.enriched_count).to eq(1)
      end
    end

    context "when enriched events are not ready" do
      before do
        create_enriched_expanded_event
      end

      it "returns not_ready status without state transition" do
        result = service.call

        subscription_migration.reload
        expect(result.status).to eq(:not_ready)
        expect(result.enriched_count).to eq(1)
        expect(subscription_migration).to be_waiting_for_enrichment
        expect(subscription_migration.attempts).to eq(1)
      end
    end

    context "when max attempts reached" do
      let(:attempt) { 10 }

      before do
        create_enriched_expanded_event
      end

      it "transitions to failed" do
        result = service.call

        subscription_migration.reload
        expect(result.status).to eq(:max_attempts_reached)
        expect(subscription_migration).to be_failed
        expect(subscription_migration.attempts).to eq(10)
        expect(subscription_migration.error_message).to include("10 attempts")
      end
    end

    context "when subscription migration is not in waiting_for_enrichment state" do
      let(:subscription_migration) do
        create(:enriched_store_subscription_migration, :comparing,
          enriched_store_migration: migration,
          organization:,
          subscription:)
      end

      it "returns without action" do
        result = service.call
        expect(result).to be_success
        expect(result.status).to be_nil
        expect(subscription_migration.reload).to be_comparing
      end
    end
  end
end
