# frozen_string_literal: true

class AddOrganizationIdToPaymentProviderCustomers < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_reference :payment_provider_customers, :organization, type: :uuid, index: {algorithm: :concurrently}
  end
end
