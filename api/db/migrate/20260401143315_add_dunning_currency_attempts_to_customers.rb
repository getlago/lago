# frozen_string_literal: true

class AddDunningCurrencyAttemptsToCustomers < ActiveRecord::Migration[8.0]
  def change
    add_column :customers, :dunning_currency_attempts, :jsonb, default: {}, null: false
  end
end
