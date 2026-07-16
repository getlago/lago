# frozen_string_literal: true

class AddBillingEntityToSubscriptions < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_reference :subscriptions, :billing_entity, type: :uuid, null: true,
      index: {algorithm: :concurrently}
    add_foreign_key :subscriptions, :billing_entities, validate: false
  end
end
