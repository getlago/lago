# frozen_string_literal: true

class AddOrganizationIdFkToPaymentProviderCustomers < ActiveRecord::Migration[7.2]
  def change
    add_foreign_key :payment_provider_customers, :organizations, validate: false
  end
end
