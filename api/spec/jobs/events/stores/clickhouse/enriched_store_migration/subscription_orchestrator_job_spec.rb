# frozen_string_literal: true

require "rails_helper"

RSpec.describe Events::Stores::Clickhouse::EnrichedStoreMigration::SubscriptionOrchestratorJob, type: :job do
  let(:organization) { create(:organization) }
  let(:migration) { create(:enriched_store_migration, :processing, organization:) }
  let(:subscription) { create(:subscription, organization:) }
  let(:subscription_migration) do
    create(:enriched_store_subscription_migration,
      enriched_store_migration: migration,
      organization:,
      subscription:)
  end

  before do
    allow(Events::Stores::Clickhouse::EnrichedStoreMigration::SubscriptionOrchestratorService)
      .to receive(:call!)
  end

  describe "#perform" do
    it "calls the SubscriptionOrchestratorService" do
      described_class.perform_now(subscription_migration)

      expect(Events::Stores::Clickhouse::EnrichedStoreMigration::SubscriptionOrchestratorService)
        .to have_received(:call!).with(subscription_migration:)
    end
  end
end
