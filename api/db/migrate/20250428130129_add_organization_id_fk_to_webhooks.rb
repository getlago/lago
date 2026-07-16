# frozen_string_literal: true

class AddOrganizationIdFkToWebhooks < ActiveRecord::Migration[7.2]
  def change
    add_foreign_key :webhooks, :organizations, validate: false
  end
end
