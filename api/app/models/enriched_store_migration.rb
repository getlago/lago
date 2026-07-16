# frozen_string_literal: true

class EnrichedStoreMigration < ApplicationRecord
  include AASM

  belongs_to :organization

  has_many :subscription_migrations,
    class_name: "EnrichedStoreSubscriptionMigration",
    dependent: :destroy

  STATUSES = {
    pending: "pending",
    checking: "checking",
    processing: "processing",
    enabling: "enabling",
    completed: "completed",
    failed: "failed"
  }.freeze

  enum :status, STATUSES, validate: true

  aasm column: "status", timestamps: true do
    state :pending, initial: true
    state :checking
    state :processing
    state :enabling
    state :completed
    state :failed

    event :start_check do
      transitions from: :pending, to: :checking
    end

    event :start_processing do
      transitions from: :checking, to: :processing
    end

    event :start_enabling do
      transitions from: :processing, to: :enabling
    end

    event :complete do
      transitions from: :enabling, to: :completed
    end

    event :fail do
      transitions from: [:pending, :checking, :processing, :enabling], to: :failed
    end

    event :retry_migration do
      transitions from: :failed, to: :pending
    end
  end

  def all_subscriptions_completed?
    subscription_migrations.exists? && subscription_migrations.where.not(status: :completed).none?
  end
end

# == Schema Information
#
# Table name: enriched_store_migrations
# Database name: primary
#
#  id              :uuid             not null, primary key
#  completed_at    :datetime
#  error_message   :text
#  started_at      :datetime
#  status          :enum             default("pending"), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  organization_id :uuid             not null
#
# Indexes
#
#  index_enriched_store_migrations_on_organization_id  (organization_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (organization_id => organizations.id)
#
