# frozen_string_literal: true

class AssignCustomersToBillingEntities < ActiveRecord::Migration[7.2]
  class BillingEntity < ApplicationRecord
    attribute :subscription_invoice_issuing_date_anchor, :string, default: "next_period_start"
    attribute :subscription_invoice_issuing_date_adjustment, :string, default: "keep_anchor"
  end

  class Customer < ApplicationRecord
    self.ignored_columns = []

    attribute :subscription_invoice_issuing_date_anchor, :string, default: "next_period_start"
    attribute :subscription_invoice_issuing_date_adjustment, :string, default: "keep_anchor"
  end

  def change
    # NOTE: ensure first billing entity has the same id as the organization to ease the migration to multi entities.
    BillingEntity.where("id != organization_id").find_in_batches(batch_size: 1000) do |batch|
      BillingEntity.where(id: batch.pluck(:id))
        .update_all("id = organization_id") # rubocop:disable Rails/SkipsModelValidations
    end

    # NOTE: Update all customers to have the same billing_entity_id as organization_id
    Customer.where("billing_entity_id != organization_id").or(Customer.where(billing_entity_id: nil)).find_in_batches(batch_size: 1000) do |batch|
      Customer.where(id: batch.pluck(:id))
        .update_all("billing_entity_id = organization_id") # rubocop:disable Rails/SkipsModelValidations
    end
  end
end
