# frozen_string_literal: true

class CreateEntitlementSubscriptionFeatureRemovals < ActiveRecord::Migration[8.0]
  def change
    create_table :entitlement_subscription_feature_removals, id: :uuid do |t|
      t.references :organization, null: false, foreign_key: true, type: :uuid
      t.references :entitlement_feature, null: false, foreign_key: true, type: :uuid
      t.references :subscription, null: false, foreign_key: true, type: :uuid
      t.datetime :deleted_at, index: true
      t.timestamps

      t.index [:subscription_id, :entitlement_feature_id], unique: true, where: "deleted_at IS NULL"
    end
  end
end
