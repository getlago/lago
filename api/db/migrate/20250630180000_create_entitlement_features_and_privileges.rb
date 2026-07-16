# frozen_string_literal: true

class CreateEntitlementFeaturesAndPrivileges < ActiveRecord::Migration[8.0]
  def change
    create_enum :entitlement_privilege_value_types, %w[integer string boolean select]

    create_table :entitlement_features, id: :uuid do |t|
      t.references :organization, type: :uuid, foreign_key: true, null: false, index: true
      t.string :code, null: false
      t.string :name
      t.string :description
      t.datetime :deleted_at
      t.timestamps

      t.index %w[code organization_id],
        name: "idx_features_code_unique_per_organization",
        unique: true,
        where: "deleted_at IS NULL"
    end

    create_table :entitlement_privileges, id: :uuid do |t|
      t.references :organization, type: :uuid, foreign_key: true, null: false, index: true
      t.references :entitlement_feature, type: :uuid, foreign_key: true, null: false, index: true
      t.string :code, null: false
      t.string :name
      t.enum :value_type, enum_type: "entitlement_privilege_value_types", null: false
      # NOTE: NOT NULL see: db/migrate/20250722094047_change_privilege_config_to_not_null.rb
      t.jsonb :config, default: {}
      t.datetime :deleted_at
      t.timestamps

      t.index %w[code entitlement_feature_id],
        name: "idx_privileges_code_unique_per_feature",
        unique: true
      # where: "deleted_at IS NULL" forgotten but added in db/migrate/20250717092012_fix_privilege_index.rb
    end
  end
end
