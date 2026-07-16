# frozen_string_literal: true

class AddBillingEntityIdNotNullCheckConstraintToFees < ActiveRecord::Migration[7.2]
  def change
    add_check_constraint :fees, "billing_entity_id IS NOT NULL", name: "fees_billing_entity_id_null", validate: false
  end
end
