# frozen_string_literal: true

class AddCustomerIdToPayments < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_reference :payments, :customer, null: true, index: {algorithm: :concurrently}, type: :uuid

    add_check_constraint :payments,
      "customer_id IS NOT NULL",
      name: "payments_customer_id_null",
      validate: false
  end
end
