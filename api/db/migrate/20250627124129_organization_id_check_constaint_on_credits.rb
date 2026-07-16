# frozen_string_literal: true

class OrganizationIdCheckConstaintOnCredits < ActiveRecord::Migration[8.0]
  def change
    add_check_constraint :credits,
      "organization_id IS NOT NULL",
      name: "credits_organization_id_null",
      validate: false
  end
end
