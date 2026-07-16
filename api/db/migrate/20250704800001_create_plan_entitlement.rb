# frozen_string_literal: true

class CreatePlanEntitlement < ActiveRecord::Migration[8.0]
  def change
    create_table :entitlement_entitlements, id: :uuid do |t|
      t.references :organization, null: false, foreign_key: true, type: :uuid
      t.references :entitlement_feature, null: false, foreign_key: true, type: :uuid
      t.references :plan, null: false, foreign_key: true, type: :uuid
      t.datetime :deleted_at
      t.timestamps

      t.index %w[entitlement_feature_id plan_id],
        name: "idx_on_entitlement_feature_id_plan_id_c45949ea26",
        unique: true,
        where: "deleted_at IS NULL"
    end

    create_table :entitlement_entitlement_values, id: :uuid do |t|
      t.references :organization, null: false, foreign_key: true, type: :uuid
      t.references :entitlement_privilege, null: false, foreign_key: true, type: :uuid
      t.references :entitlement_entitlement, null: false, foreign_key: true, type: :uuid
      t.string :value, null: false
      t.datetime :deleted_at
      t.timestamps

      t.index %w[entitlement_privilege_id entitlement_entitlement_id],
        unique: true,
        where: "deleted_at IS NULL"
    end
  end
end
