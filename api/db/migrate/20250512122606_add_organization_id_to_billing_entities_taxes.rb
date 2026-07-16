# frozen_string_literal: true

class AddOrganizationIdToBillingEntitiesTaxes < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_reference :billing_entities_taxes, :organization, type: :uuid, index: {algorithm: :concurrently}
  end
end
