# frozen_string_literal: true

require "rails_helper"

RSpec.describe Events::Stores::Clickhouse::EnrichedStoreMigration::WaitForEnrichmentJob, type: :job do
  let(:organization) { create(:organization) }
  let(:migration) { create(:enriched_store_migration, :processing, organization:) }
  let(:subscription) { create(:subscription, organization:) }
  let(:subscription_migration) do
    create(:enriched_store_subscription_migration, :waiting_for_enrichment,
      enriched_store_migration: migration,
      organization:,
      subscription:,
      events_reprocessed_count: 100,
      billable_metric_codes: ["code1"])
  end

  let(:service_result) do
    result = Events::Stores::Clickhouse::EnrichedStoreMigration::WaitForEnrichmentService::Result.new
    result.status = status
    result.enriched_count = 50
    result
  end

  before do
    allow(Events::Stores::Clickhouse::EnrichedStoreMigration::WaitForEnrichmentService)
      .to receive(:call!).and_return(service_result)
  end

  describe "#perform" do
    context "when service returns ready" do
      let(:status) { :ready }

      it "does not re-enqueue" do
        described_class.perform_now(subscription_migration, 1)

        expect(described_class).not_to have_been_enqueued
      end
    end

    context "when service returns not_ready" do
      let(:status) { :not_ready }

      it "re-enqueues with backoff" do
        freeze_time do
          expect { described_class.perform_now(subscription_migration, 1) }.to have_enqueued_job(described_class)
            .with(subscription_migration, 2)
            .at(5.minutes.from_now)
        end
      end
    end

    context "when service returns not_ready on later attempt" do
      let(:status) { :not_ready }

      it "uses the correct backoff schedule" do
        freeze_time do
          expect { described_class.perform_now(subscription_migration, 2) }.to have_enqueued_job(described_class)
            .with(subscription_migration, 3)
            .at(10.minutes.from_now)
        end
      end
    end

    context "when service returns max_attempts_reached" do
      let(:status) { :max_attempts_reached }

      it "does not re-enqueue" do
        expect { described_class.perform_now(subscription_migration, 10) }.not_to have_enqueued_job(described_class)
      end
    end
  end
end
