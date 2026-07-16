# frozen_string_literal: true

class NotNullOrganizationIdOnPaymentProviderCustomers < ActiveRecord::Migration[8.0]
  def up
    validate_check_constraint :payment_provider_customers, name: "payment_provider_customers_organization_id_not_null"
    change_column_null :payment_provider_customers, :organization_id, false
    remove_check_constraint :payment_provider_customers, name: "payment_provider_customers_organization_id_not_null"
  end

  def down
    add_check_constraint :payment_provider_customers, "organization_id IS NOT NULL", name: "payment_provider_customers_organization_id_not_null", validate: false
    change_column_null :payment_provider_customers, :organization_id, true
  end
end
