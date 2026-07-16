# frozen_string_literal: true

class EnsureAllBillingEntitiesHaveInvoiceSequentialId < ActiveRecord::Migration[7.2]
  class BillingEntity < ApplicationRecord
    attribute :subscription_invoice_issuing_date_anchor, :string, default: "next_period_start"
    attribute :subscription_invoice_issuing_date_adjustment, :string, default: "keep_anchor"
  end

  def change
    BillingEntity.find_each do |billing_entity|
      last_billing_entity_sequential_id = billing_entity.invoices.non_self_billed.with_generated_number.maximum(:billing_entity_sequential_id) || 0
      invoices_count = billing_entity.invoices.non_self_billed.with_generated_number.count

      next if last_billing_entity_sequential_id == invoices_count

      last_invoice = billing_entity.invoices.non_self_billed.with_generated_number.where(billing_entity_sequential_id: nil).order(created_at: :desc).limit(1)
      last_invoice.update_all(billing_entity_sequential_id: invoices_count) # rubocop:disable Rails/SkipsModelValidations
    end
  end
end
