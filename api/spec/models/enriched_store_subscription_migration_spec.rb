# frozen_string_literal: true

require "rails_helper"

RSpec.describe EnrichedStoreSubscriptionMigration do
  subject(:subscription_migration) { create(:enriched_store_subscription_migration) }

  describe "enums" do
    it do
      expect(subject).to define_enum_for(:status)
        .backed_by_column_of_type(:enum)
        .validating
        .with_values(
          pending: "pending",
          comparing: "comparing",
          reprocessing: "reprocessing",
          waiting_for_enrichment: "waiting_for_enrichment",
          deduplicating: "deduplicating",
          dedup_paused: "dedup_paused",
          validating: "validating",
          completed: "completed",
          failed: "failed"
        )
    end
  end

  describe "associations" do
    it do
      expect(subject).to belong_to(:enriched_store_migration)
      expect(subject).to belong_to(:subscription)
      expect(subject).to belong_to(:organization)
    end
  end

  describe "AASM transitions" do
    describe "#start_comparing" do
      it "transitions from pending to comparing" do
        expect(subscription_migration).to be_pending
        subscription_migration.start_comparing!
        expect(subscription_migration).to be_comparing
      end
    end

    describe "#start_reprocessing" do
      subject(:subscription_migration) { create(:enriched_store_subscription_migration, :comparing) }

      it "transitions from comparing to reprocessing" do
        subscription_migration.start_reprocessing!
        expect(subscription_migration).to be_reprocessing
      end
    end

    describe "#start_waiting" do
      subject(:subscription_migration) { create(:enriched_store_subscription_migration, :reprocessing) }

      it "transitions from reprocessing to waiting_for_enrichment" do
        subscription_migration.start_waiting!
        expect(subscription_migration).to be_waiting_for_enrichment
      end
    end

    describe "#start_deduplicating" do
      subject(:subscription_migration) { create(:enriched_store_subscription_migration, :waiting_for_enrichment) }

      it "transitions from waiting_for_enrichment to deduplicating" do
        subscription_migration.start_deduplicating!
        expect(subscription_migration).to be_deduplicating
      end
    end

    describe "#pause_dedup" do
      subject(:subscription_migration) { create(:enriched_store_subscription_migration, :deduplicating) }

      it "transitions from deduplicating to dedup_paused" do
        subscription_migration.pause_dedup!
        expect(subscription_migration).to be_dedup_paused
      end
    end

    describe "#start_validating" do
      %i[deduplicating dedup_paused].each do |state|
        it "transitions from #{state} to validating" do
          record = create(:enriched_store_subscription_migration, state)
          record.start_validating!
          expect(record).to be_validating
        end
      end
    end

    describe "#complete" do
      %i[comparing validating].each do |state|
        it "transitions from #{state} to completed" do
          record = create(:enriched_store_subscription_migration, state)
          record.complete!
          expect(record).to be_completed
        end
      end
    end

    describe "#fail" do
      %i[pending comparing reprocessing waiting_for_enrichment deduplicating dedup_paused validating].each do |state|
        it "transitions from #{state} to failed" do
          record = if state == :pending
            create(:enriched_store_subscription_migration)
          else
            create(:enriched_store_subscription_migration, state)
          end

          record.fail!
          expect(record).to be_failed
        end
      end
    end

    describe "#retry_migration" do
      subject(:subscription_migration) { create(:enriched_store_subscription_migration, :failed) }

      it "transitions from failed to pending" do
        subscription_migration.retry_migration!
        expect(subscription_migration).to be_pending
      end
    end
  end
end
