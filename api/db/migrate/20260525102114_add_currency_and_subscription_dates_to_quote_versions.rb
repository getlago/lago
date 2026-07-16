# frozen_string_literal: true

class AddCurrencyAndSubscriptionDatesToQuoteVersions < ActiveRecord::Migration[8.0]
  def change
    add_column :quote_versions, :currency, :string
    add_column :quote_versions, :start_date, :date
    add_column :quote_versions, :end_date, :date
  end
end
