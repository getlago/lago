# frozen_string_literal: true

class EnrichedStoreSubscriptionMigration < ApplicationRecord
  include AASM

  belongs_to :enriched_store_migration
  belongs_to :subscription
  belongs_to :organization

  STATUSES = {
    pending: "pending",
    comparing: "comparing",
    reprocessing: "reprocessing",
    waiting_for_enrichment: "waiting_for_enrichment",
    deduplicating: "deduplicating",
    dedup_paused: "dedup_paused",
    validating: "validating",
    completed: "completed",
    failed: "failed"
  }.freeze

  enum :status, STATUSES, validate: true

  aasm column: "status", timestamps: true do
    state :pending, initial: true
    state :comparing
    state :reprocessing
    state :waiting_for_enrichment
    state :deduplicating
    state :dedup_paused
    state :validating
    state :completed
    state :failed

    event :start_comparing do
      transitions from: :pending, to: :comparing
    end

    event :start_reprocessing do
      transitions from: :comparing, to: :reprocessing
    end

    event :start_waiting do
      transitions from: :reprocessing, to: :waiting_for_enrichment
    end

    event :start_deduplicating do
      transitions from: :waiting_for_enrichment, to: :deduplicating
    end

    event :pause_dedup do
      transitions from: :deduplicating, to: :dedup_paused
    end

    event :start_validating do
      transitions from: [:deduplicating, :dedup_paused], to: :validating
    end

    event :complete do
      transitions from: [:comparing, :validating], to: :completed
    end

    event :fail do
      transitions from: [
        :pending, :comparing, :reprocessing, :waiting_for_enrichment,
        :deduplicating, :dedup_paused, :validating
      ], to: :failed
    end

    event :retry_migration do
      transitions from: :failed, to: :pending
    end
  end
end

# == Schema Information
#
# Table name: enriched_store_subscription_migrations
# Database name: primary
#
#  id                          :uuid             not null, primary key
#  attempts                    :integer          default(0)
#  billable_metric_codes       :jsonb
#  comparison_results          :jsonb
#  completed_at                :datetime
#  dedup_pending_queries       :jsonb
#  duplicates_removed_count    :integer          default(0)
#  error_message               :text
#  events_reprocessed_count    :integer          default(0)
#  started_at                  :datetime
#  status                      :enum             default("pending"), not null
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  enriched_store_migration_id :uuid             not null
#  organization_id             :uuid             not null
#  subscription_id             :uuid             not null
#
# Indexes
#
#  idx_enriched_store_sub_migrations_on_migration_and_subscription  (enriched_store_migration_id,subscription_id) UNIQUE
#  idx_on_enriched_store_migration_id_e409c5dc43                    (enriched_store_migration_id)
#  idx_on_organization_id_2be2ef98ea                                (organization_id)
#  idx_on_subscription_id_b41afd08e0                                (subscription_id)
#
# Foreign Keys
#
#  fk_rails_...  (enriched_store_migration_id => enriched_store_migrations.id)
#  fk_rails_...  (organization_id => organizations.id)
#  fk_rails_...  (subscription_id => subscriptions.id)
#
