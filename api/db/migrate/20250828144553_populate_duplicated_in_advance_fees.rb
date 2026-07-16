# frozen_string_literal: true

class PopulateDuplicatedInAdvanceFees < ActiveRecord::Migration[8.0]
  def up
    sql = <<~SQL
      SELECT organization_id, pay_in_advance_event_transaction_id, charge_id, charge_filter_id
      FROM fees
      WHERE fees.deleted_at IS NULL
        AND fees.pay_in_advance = TRUE
        AND fees.pay_in_advance_event_transaction_id IS NOT NULL
      GROUP BY pay_in_advance_event_transaction_id, charge_id, charge_filter_id, organization_id
      HAVING COUNT(*) > 1
    SQL

    ActiveRecord::Base.connection.select_all(sql).rows.each do |row|
      Fee.where(
        organization_id: row[0],
        pay_in_advance_event_transaction_id: row[1],
        charge_id: row[2],
        charge_filter_id: row[3],
        pay_in_advance: true
      ).update_all(duplicated_in_advance: true) # rubocop:disable Rails/SkipsModelValidations
    end
  end
end
