# frozen_string_literal: true

class OrganizationIdCheckConstaintOnSubscriptions < ActiveRecord::Migration[8.0]
  def change
    add_check_constraint :subscriptions,
      "organization_id IS NOT NULL",
      name: "subscriptions_organization_id_not_null",
      validate: false
  end
end
