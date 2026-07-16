# frozen_string_literal: true

class AddOrganizationIdFkToCredits < ActiveRecord::Migration[7.2]
  def change
    add_foreign_key :credits, :organizations, validate: false
  end
end
