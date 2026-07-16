# frozen_string_literal: true

class DropInvoiceErrorTable < ActiveRecord::Migration[7.1]
  def up
    drop_table :invoice_errors
  end

  def down
    create_table :invoice_errors, id: :uuid do |t|
      t.text :backtrace
      t.json :invoice
      t.json :subscriptions
      t.json :error

      t.timestamps
    end
  end
end
