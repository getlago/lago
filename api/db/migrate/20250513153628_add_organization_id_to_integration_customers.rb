# frozen_string_literal: true

class AddOrganizationIdToIntegrationCustomers < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_reference :integration_customers, :organization, type: :uuid, index: {algorithm: :concurrently}
  end
end
