# frozen_string_literal: true

require "rails_helper"

RSpec.describe EnrichedStoreMigration do
  subject(:migration) { create(:enriched_store_migration) }

  describe "enums" do
    it do
      expect(subject).to define_enum_for(:status)
        .backed_by_column_of_type(:enum)
        .validating
        .with_values(
          pending: "pending",
          checking: "checking",
          processing: "processing",
          enabling: "enabling",
          completed: "completed",
          failed: "failed"
        )
    end
  end

  describe "associations" do
    it do
      expect(subject).to belong_to(:organization)
      expect(subject).to have_many(:subscription_migrations)
        .class_name("EnrichedStoreSubscriptionMigration")
        .dependent(:destroy)
    end
  end

  describe "AASM transitions" do
    describe "#start_check" do
      it "transitions from pending to checking" do
        expect(migration).to be_pending
        migration.start_check!
        expect(migration).to be_checking
      end
    end

    describe "#start_processing" do
      subject(:migration) { create(:enriched_store_migration, :checking) }

      it "transitions from checking to processing" do
        migration.start_processing!
        expect(migration).to be_processing
      end
    end

    describe "#start_enabling" do
      subject(:migration) { create(:enriched_store_migration, :processing) }

      it "transitions from processing to enabling" do
        migration.start_enabling!
        expect(migration).to be_enabling
      end
    end

    describe "#complete" do
      subject(:migration) { create(:enriched_store_migration, :enabling) }

      it "transitions from enabling to completed" do
        migration.complete!
        expect(migration).to be_completed
      end
    end

    describe "#fail" do
      %i[pending checking processing enabling].each do |state|
        it "transitions from #{state} to failed" do
          record = if state == :pending
            create(:enriched_store_migration)
          else
            create(:enriched_store_migration, state)
          end

          record.fail!
          expect(record).to be_failed
        end
      end
    end

    describe "#retry_migration" do
      subject(:migration) { create(:enriched_store_migration, :failed) }

      it "transitions from failed to pending" do
        migration.retry_migration!
        expect(migration).to be_pending
      end
    end
  end

  describe "#all_subscriptions_completed?" do
    it "returns false when there are no subscription migrations" do
      expect(migration).not_to be_all_subscriptions_completed
    end

    it "returns true when all subscription migrations are completed" do
      create(:enriched_store_subscription_migration, :completed, enriched_store_migration: migration)
      create(:enriched_store_subscription_migration, :completed, enriched_store_migration: migration)

      expect(migration).to be_all_subscriptions_completed
    end

    it "returns false when some subscription migrations are not completed" do
      create(:enriched_store_subscription_migration, :completed, enriched_store_migration: migration)
      create(:enriched_store_subscription_migration, enriched_store_migration: migration)

      expect(migration).not_to be_all_subscriptions_completed
    end
  end
end
