# frozen_string_literal: true

module Taxes
  class DestroyService < BaseService
    Result = BaseResult[:tax]

    def initialize(tax:)
      @tax = tax

      super
    end

    def call
      return result.not_found_failure!(resource: "tax") unless tax

      result.tax = tax

      return result if tax.discarded?

      # NOTE: we must retrieve the list of draft invoice before proceeding to destroy
      #       as we need the applied_tax relation
      draft_invoice_ids

      ActiveRecord::Base.transaction do
        tax.billing_entities.each do |billing_entity|
          BillingEntities::Taxes::RemoveTaxesService.call!(billing_entity:, tax_codes: [tax.code])
        end

        tax.applied_taxes.delete_all
        tax.draft_fee_taxes.delete_all
        tax.draft_invoice_taxes.delete_all
        tax.credit_notes_taxes.delete_all
        tax.add_ons_taxes.delete_all
        tax.plans_taxes.delete_all
        tax.charges_taxes.delete_all
        tax.commitments_taxes.delete_all
        tax.fixed_charges_taxes.delete_all

        tax.deleted_at = Time.current
        tax.save!
      end

      Invoice.where(id: draft_invoice_ids).update_all(ready_to_be_refreshed: true) # rubocop:disable Rails/SkipsModelValidations

      result
    end

    private

    attr_reader :tax

    def draft_invoice_ids
      @draft_invoice_ids ||= tax.organization.invoices
        .where(customer_id: tax.applicable_customers.select(:id))
        .draft
        .pluck(:id)
    end
  end
end
