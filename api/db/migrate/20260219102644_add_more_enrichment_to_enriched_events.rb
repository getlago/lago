# frozen_string_literal: true

class AddMoreEnrichmentToEnrichedEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :enriched_events, :operation_type, :string, null: true
    add_column :enriched_events, :precise_total_amount_cents, :decimal, precision: 40, scale: 15
    add_column :enriched_events, :target_wallet_code, :string, null: true
  end
end
