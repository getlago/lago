# frozen_string_literal: true

class AddOrganizationIdFkToPaymants < ActiveRecord::Migration[7.2]
  def change
    add_foreign_key :payments, :organizations, validate: false
  end
end
