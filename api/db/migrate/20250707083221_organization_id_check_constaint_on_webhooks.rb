# frozen_string_literal: true

class OrganizationIdCheckConstaintOnWebhooks < ActiveRecord::Migration[8.0]
  def change
    add_check_constraint :webhooks,
      "organization_id IS NOT NULL",
      name: "webhooks_organization_id_null",
      validate: false
  end
end
