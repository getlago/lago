# frozen_string_literal: true

class MigrateDeletedPaymentProviderCustomers < ActiveRecord::Migration[8.0]
  def up
    safety_assured do
      execute <<~SQL.squish
        UPDATE payment_provider_customers
        SET organization_id = (SELECT organization_id FROM customers WHERE customers.id = customer_id)
        WHERE organization_id IS NULL
      SQL
    end
  end
end
