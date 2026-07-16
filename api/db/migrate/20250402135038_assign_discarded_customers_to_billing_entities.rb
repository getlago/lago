# frozen_string_literal: true

class AssignDiscardedCustomersToBillingEntities < ActiveRecord::Migration[7.2]
  class Customer < ApplicationRecord
    self.ignored_columns = []

    attribute :subscription_invoice_issuing_date_anchor, :string, default: "next_period_start"
    attribute :subscription_invoice_issuing_date_adjustment, :string, default: "keep_anchor"
  end

  def up
    Customer.where("billing_entity_id != organization_id").or(Customer.where(billing_entity_id: nil)).find_in_batches(batch_size: 1000) do |batch|
      Customer.where(id: batch.pluck(:id))
        .update_all("billing_entity_id = organization_id") # rubocop:disable Rails/SkipsModelValidations
    end
  end

  def down
  end
end
