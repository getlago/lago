# frozen_string_literal: true

class AddDeletedAtConditionToIndexPaymentMethodsOnProviderCustomerAndProviderMethod < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    remove_index :payment_methods,
      name: :index_payment_methods_on_provider_customer_and_provider_method,
      algorithm: :concurrently

    add_index :payment_methods,
      [:payment_provider_customer_id, :provider_method_id],
      unique: true,
      name: :index_payment_methods_on_provider_customer_and_provider_method,
      where: "deleted_at IS NULL",
      algorithm: :concurrently
  end

  def down
    remove_index :payment_methods,
      name: :index_payment_methods_on_provider_customer_and_provider_method,
      algorithm: :concurrently,
      if_exists: true

    add_index :payment_methods,
      [:payment_provider_customer_id, :provider_method_id],
      unique: true,
      name: :index_payment_methods_on_provider_customer_and_provider_method,
      algorithm: :concurrently
  end
end
