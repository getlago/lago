# frozen_string_literal: true

class AddOrganizationIdToPlansTaxes < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_reference :plans_taxes, :organization, type: :uuid, index: {algorithm: :concurrently}
  end
end
