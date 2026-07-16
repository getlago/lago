# frozen_string_literal: true

class FixStaleBillingEntitySequentialIdToBeUniq < ActiveRecord::Migration[8.0]
  class BillingEntity < ApplicationRecord
    attribute :subscription_invoice_issuing_date_anchor, :string, default: "next_period_start"
    attribute :subscription_invoice_issuing_date_adjustment, :string, default: "keep_anchor"
  end

  class Invoice < ApplicationRecord
    scope :non_self_billed, -> { where.not(self_billed: true) }
    scope :with_generated_number, -> { where(status: %w[finalized voided]) }
  end

  def up
    # BillingEntities::ChangeInvoiceNumberingService -- if we switch from per_customer
    # to per_billing_entity, we'll recalculate the billing_entity_sequential_id
    BillingEntity.where(document_numbering: "per_customer").find_each do |billing_entity|
      # find invoices with duplicated billing_entity_sequential_id
      duplicates = Invoice.where(billing_entity_id: billing_entity.id)
        .non_self_billed.with_generated_number
        .where.not(billing_entity_sequential_id: nil)
        .group(:billing_entity_sequential_id)
        .having("COUNT(*) > 1")
        .pluck(:billing_entity_sequential_id)
      next if duplicates.empty?

      # update the billing_entity_sequential_id to NULL for the duplicated invoices
      # rubocop:disable Rails/SkipsModelValidations
      Invoice.where(billing_entity_id: billing_entity.id)
        .non_self_billed.with_generated_number
        .where(billing_entity_sequential_id: duplicates)
        .update_all("billing_entity_sequential_id = NULL")
      # rubocop:enable Rails/SkipsModelValidations
    end

    BillingEntity.where(document_numbering: "per_billing_entity").find_each do |billing_entity|
      # group invoices by billing_entity_sequential_id and find groups with more than 1 invoice
      duplicates = Invoice.where(billing_entity_id: billing_entity.id)
        .non_self_billed.with_generated_number
        .where.not(billing_entity_sequential_id: nil)
        .group(:billing_entity_sequential_id)
        .having("COUNT(*) > 1")
        .pluck(:billing_entity_sequential_id)
      next if duplicates.empty?

      invoices_count = Invoice.where(billing_entity_id: billing_entity.id, billing_entity_sequential_id: duplicates).count
      latest_invoice = Invoice.where(billing_entity_id: billing_entity.id, billing_entity_sequential_id: duplicates).order(:created_at).last
      Rails.logger.info "Found #{duplicates.count} duplicates for billing_entity: #{billing_entity.name}; Affected invoices: #{invoices_count}; Latest invoice: (#{latest_invoice.created_at})"

      # find the highest billing_entity_sequential_id for the billing_entity
      existing_max_number = Invoice.where(billing_entity_id: billing_entity.id)
        .non_self_billed.with_generated_number
        .maximum(:billing_entity_sequential_id)

      if duplicates.max >= existing_max_number
        Rails.logger.warn("-" * 80)
        Rails.logger.warn "billing_entity: #{billing_entity.name}"
        Rails.logger.warn "WARNING: DUPLICATED LATEST BILLING_ENTITY_SEQUENTIAL_ID: #{duplicates.max} >= #{existing_max_number}"
        Rails.logger.warn("-" * 80)
        next
      end

      # for each duplicate, set the billing_entity_sequential_id to NULL
      # rubocop:disable Rails/SkipsModelValidations
      Invoice.where(billing_entity_id: billing_entity.id, billing_entity_sequential_id: duplicates)
        .update_all("billing_entity_sequential_id = NULL")
      # rubocop:enable Rails/SkipsModelValidations
    end
  end

  def down
    # No down migration needed
  end
end
