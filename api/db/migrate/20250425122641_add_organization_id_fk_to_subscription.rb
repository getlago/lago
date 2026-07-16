# frozen_string_literal: true

class AddOrganizationIdFkToSubscription < ActiveRecord::Migration[7.2]
  def change
    add_foreign_key :subscriptions, :organizations, validate: false
  end
end
