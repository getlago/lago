# frozen_string_literal: true

class AddResponseKeyToWebhooks < ActiveRecord::Migration[8.0]
  def change
    add_column :webhooks, :response_key, :string
  end
end
