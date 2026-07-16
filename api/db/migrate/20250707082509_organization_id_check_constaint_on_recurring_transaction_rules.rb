# frozen_string_literal: true

class OrganizationIdCheckConstaintOnRecurringTransactionRules < ActiveRecord::Migration[8.0]
  def change
    add_check_constraint :recurring_transaction_rules,
      "organization_id IS NOT NULL",
      name: "recurring_transaction_rules_organization_id_null",
      validate: false
  end
end
