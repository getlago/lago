# frozen_string_literal: true

class AddOrganizationIdFkToRefunds < ActiveRecord::Migration[7.2]
  def change
    add_foreign_key :refunds, :organizations, validate: false
  end
end
