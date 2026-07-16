# frozen_string_literal: true

class ValidatePaymentProviderCustomersOrganizationsForeignKey < ActiveRecord::Migration[7.2]
  def change
    validate_foreign_key :payment_provider_customers, :organizations
  end
end
