# frozen_string_literal: true

class AddOrganizationToAddOnsTaxes < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_reference :add_ons_taxes, :organization, type: :uuid, index: {algorithm: :concurrently}
  end
end
