# frozen_string_literal: true

class AddOrganizationIdToCustomersTaxes < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_reference :customers_taxes, :organization, type: :uuid, index: {algorithm: :concurrently}
  end
end
