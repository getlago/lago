# frozen_string_literal: true

class AddOrganizationIdToRecurringTransactionRules < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_reference :recurring_transaction_rules, :organization, type: :uuid, index: {algorithm: :concurrently}
  end
end
