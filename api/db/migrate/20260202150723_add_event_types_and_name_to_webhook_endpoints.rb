# frozen_string_literal: true

class AddEventTypesAndNameToWebhookEndpoints < ActiveRecord::Migration[8.0]
  def change
    add_column :webhook_endpoints, :event_types, :string, array: true
    add_column :webhook_endpoints, :name, :string
  end
end
