# frozen_string_literal: true

class AddDisableProgressiveBillingOnSubscription < ActiveRecord::Migration[8.0]
  def change
    add_column :subscriptions, :progressive_billing_disabled, :boolean, default: false, null: false
  end
end
