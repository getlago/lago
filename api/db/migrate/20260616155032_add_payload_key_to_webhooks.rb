# frozen_string_literal: true

class AddPayloadKeyToWebhooks < ActiveRecord::Migration[8.0]
  def change
    add_column :webhooks, :payload_key, :string
  end
end
