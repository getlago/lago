# frozen_string_literal: true

class CreateEnrichedStoreSubscriptionMigrations < ActiveRecord::Migration[8.0]
  def up
    create_enum :enriched_store_sub_migration_status, %w[
      pending comparing reprocessing waiting_for_enrichment
      deduplicating dedup_paused validating completed failed
    ]

    create_table :enriched_store_subscription_migrations, id: :uuid do |t|
      t.references :enriched_store_migration, type: :uuid, null: false, foreign_key: true
      t.references :subscription, type: :uuid, null: false, foreign_key: true
      t.references :organization, type: :uuid, null: false, foreign_key: true, index: true
      t.enum :status, enum_type: "enriched_store_sub_migration_status", null: false, default: "pending"
      t.jsonb :billable_metric_codes, default: []
      t.integer :events_reprocessed_count, default: 0
      t.integer :duplicates_removed_count, default: 0
      t.jsonb :dedup_pending_queries, default: []
      t.jsonb :comparison_results, default: {}
      t.text :error_message
      t.datetime :started_at
      t.datetime :completed_at
      t.integer :attempts, default: 0

      t.timestamps
    end

    add_index :enriched_store_subscription_migrations,
      [:enriched_store_migration_id, :subscription_id],
      unique: true,
      name: "idx_enriched_store_sub_migrations_on_migration_and_subscription"
  end

  def down
    drop_table :enriched_store_subscription_migrations
    drop_enum :enriched_store_sub_migration_status
  end
end
