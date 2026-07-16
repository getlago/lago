# frozen_string_literal: true

class ValidateForeignKeyBillingEntitiesOnFees < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def up
    # Validate foreign key in a separate transaction
    validate_foreign_key :fees, :billing_entities
  end
end
