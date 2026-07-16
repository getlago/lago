# frozen_string_literal: true

class AddQuotes < ActiveRecord::Migration[8.0]
  def change
    create_enum :quote_status, %w[draft approved voided]
    create_enum :quote_void_reason, %w[manual superseded cascade_of_expired cascade_of_voided]
    create_enum :quote_order_type, %w[subscription_creation subscription_amendment one_off]

    create_table :quotes, id: :uuid do |t|
      t.references :organization,
        null: false,
        foreign_key: true,
        index: false, # covered by the composite unique index below
        type: :uuid
      t.references :customer,
        null: false,
        foreign_key: true,
        type: :uuid
      t.references :subscription,
        foreign_key: true,
        type: :uuid
      t.string :number, null: false
      t.integer :sequential_id, null: false
      t.enum :order_type,
        enum_type: :quote_order_type,
        null: false
      t.timestamps

      # constraints and indices
      t.check_constraint "sequential_id > 0",
        name: "quotes_constraint_sequential_id_positive"
      t.index [:organization_id, :sequential_id],
        unique: true,
        name: "index_unique_quotes_on_organization_sequential_id"
      t.index [:organization_id, :number],
        unique: true,
        name: "index_unique_quotes_on_organization_number"
    end

    create_table :quote_versions, id: :uuid do |t|
      # identity
      t.references :organization,
        null: false,
        foreign_key: true,
        type: :uuid
      t.references :quote,
        null: false,
        foreign_key: true,
        type: :uuid
      t.integer :sequential_id, null: false # acts as version number
      # lifecycle
      t.enum :status,
        enum_type: :quote_status,
        null: false,
        default: "draft"
      t.datetime :approved_at
      t.datetime :voided_at
      t.enum :void_reason, enum_type: :quote_void_reason
      # content
      t.jsonb :billing_items
      t.text :content
      t.string :share_token
      t.timestamps

      # constraints and indices
      t.check_constraint "sequential_id > 0",
        name: "quote_versions_constraint_sequential_id_positive"
      t.check_constraint "(status = 'voided') = (void_reason IS NOT NULL AND voided_at IS NOT NULL)",
        name: "quote_versions_constraint_void_fields_match_status"
      t.check_constraint "(status = 'approved') = (approved_at IS NOT NULL)",
        name: "quote_versions_constraint_approved_at_matches_status"
      t.index [:quote_id, :sequential_id],
        unique: true,
        name: "index_unique_quote_versions_on_quote_sequential_id"
      t.index :quote_id,
        unique: true,
        where: "status IN ('draft', 'approved')",
        name: "index_unique_quote_versions_on_quote_active_status"
      t.index :share_token,
        unique: true,
        name: "index_unique_quote_versions_on_share_token"
    end

    create_table :quote_owners do |t|
      t.references :organization,
        null: false,
        foreign_key: true,
        type: :uuid
      t.references :quote,
        null: false,
        foreign_key: true,
        index: false, # covered by the composite unique index below
        type: :uuid
      t.references :user,
        null: false,
        foreign_key: true,
        type: :uuid
      t.timestamps

      t.index [:quote_id, :user_id],
        unique: true,
        name: "index_unique_quote_owners_on_quote_user"
    end
  end
end
