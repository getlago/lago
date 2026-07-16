# frozen_string_literal: true

class AddProviderPaymentMethodDataToPayments < ActiveRecord::Migration[7.1]
  def change
    add_column :payments, :provider_payment_method_data, :jsonb, null: false, default: {}
  end
end
