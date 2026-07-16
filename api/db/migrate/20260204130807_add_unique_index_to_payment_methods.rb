# frozen_string_literal: true

class AddUniqueIndexToPaymentMethods < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_index :payment_methods,
      [:payment_provider_customer_id, :provider_method_id],
      unique: true,
      name: "index_payment_methods_on_provider_customer_and_provider_method",
      algorithm: :concurrently
  end
end
