# frozen_string_literal: true

class CreateSubscriptionActivationRules < ActiveRecord::Migration[8.0]
  def change
    create_table :subscription_activation_rules, id: :uuid do |t|
      t.references :organization, type: :uuid, null: false, foreign_key: true, index: true
      t.references :subscription, type: :uuid, null: false, foreign_key: true, index: false
      t.column :type, :subscription_activation_rule_types, null: false
      t.integer :timeout_hours, null: false, default: 0
      t.column :status, :subscription_activation_rule_statuses, null: false, default: "inactive"
      t.datetime :expires_at

      t.timestamps
    end

    add_index :subscription_activation_rules, [:subscription_id, :type], unique: true
    add_index :subscription_activation_rules, [:status, :expires_at],
      where: "status = 'pending' AND expires_at IS NOT NULL",
      name: "index_activation_rules_pending_with_expiry"
  end
end
