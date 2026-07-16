# frozen_string_literal: true

class CreateEnrichedStoreMigrations < ActiveRecord::Migration[8.0]
  def up
    create_enum :enriched_store_migration_status, %w[pending checking processing enabling completed failed]

    create_table :enriched_store_migrations, id: :uuid do |t|
      t.references :organization, type: :uuid, null: false, foreign_key: true, index: {unique: true}
      t.enum :status, enum_type: "enriched_store_migration_status", null: false, default: "pending"
      t.datetime :started_at
      t.datetime :completed_at
      t.text :error_message

      t.timestamps
    end
  end

  def down
    safety_assured do
      drop_table :enriched_store_migrations
      drop_enum :enriched_store_migration_status
    end
  end
end
