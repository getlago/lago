# frozen_string_literal: true

class AddProviderPaymentMethodIdToPayments < ActiveRecord::Migration[7.2]
  def change
    add_column :payments, :provider_payment_method_id, :string, null: true
  end
end
