# frozen_string_literal: true

class BackfillAppliedGracePeriodOnDraftInvoices < ActiveRecord::Migration[7.1]
  def up
    update_query = <<~SQL
      with inv as (
        select invoices.id, COALESCE(customers.invoice_grace_period, organizations.invoice_grace_period) as grace_period
        from invoices
        INNER JOIN organizations ON organizations.id = invoices.organization_id
        INNER JOIN customers ON customers.id = invoices.customer_id
        where status = 0 -- draft
      )
      update invoices
      set applied_grace_period = inv.grace_period
      from inv
      where invoices.id = inv.id
    SQL

    safety_assured { execute(update_query) }
  end
end
