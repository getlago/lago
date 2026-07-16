# frozen_string_literal: true

class FixChargesInvoiceable < ActiveRecord::Migration[8.0]
  def up
    safety_assured do
      execute <<~SQL.squish
        UPDATE charges
        SET invoiceable = TRUE
        WHERE invoiceable = FALSE
        AND pay_in_advance = FALSE;
      SQL
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
