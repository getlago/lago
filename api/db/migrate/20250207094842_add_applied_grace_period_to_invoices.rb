# frozen_string_literal: true

class AddAppliedGracePeriodToInvoices < ActiveRecord::Migration[7.1]
  def change
    add_column :invoices, :applied_grace_period, :integer
  end
end
