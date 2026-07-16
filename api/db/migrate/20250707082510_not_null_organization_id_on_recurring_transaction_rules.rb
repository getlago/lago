# frozen_string_literal: true

class NotNullOrganizationIdOnRecurringTransactionRules < ActiveRecord::Migration[8.0]
  def up
    validate_check_constraint :recurring_transaction_rules, name: "recurring_transaction_rules_organization_id_null"
    change_column_null :recurring_transaction_rules, :organization_id, false
    remove_check_constraint :recurring_transaction_rules, name: "recurring_transaction_rules_organization_id_null"
  end

  def down
    add_check_constraint :recurring_transaction_rules, "organization_id IS NOT NULL", name: "recurring_transaction_rules_organization_id_null", validate: false
    change_column_null :recurring_transaction_rules, :organization_id, true
  end
end
