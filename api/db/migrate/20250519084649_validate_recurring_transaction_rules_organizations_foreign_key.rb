# frozen_string_literal: true

class ValidateRecurringTransactionRulesOrganizationsForeignKey < ActiveRecord::Migration[7.2]
  def change
    validate_foreign_key :recurring_transaction_rules, :organizations
  end
end
