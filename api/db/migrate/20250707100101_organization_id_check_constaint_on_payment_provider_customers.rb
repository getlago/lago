# frozen_string_literal: true

class OrganizationIdCheckConstaintOnPaymentProviderCustomers < ActiveRecord::Migration[8.0]
  def change
    add_check_constraint :payment_provider_customers,
      "organization_id IS NOT NULL",
      name: "payment_provider_customers_organization_id_not_null",
      validate: false
  end
end
