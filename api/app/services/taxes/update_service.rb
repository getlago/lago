# frozen_string_literal: true

module Taxes
  class UpdateService < BaseService
    Result = BaseResult[:tax]

    def initialize(tax:, params:)
      @tax = tax
      @params = params

      super
    end

    def call
      return result.not_found_failure!(resource: "tax") unless tax

      customer_ids = tax.applicable_customers.select(:id).to_a

      tax.name = params[:name] if params.key?(:name)
      tax.code = params[:code] if params.key?(:code)
      tax.rate = params[:rate] if params.key?(:rate)
      tax.description = params[:description] if params.key?(:description)
      tax.applied_to_organization = params[:applied_to_organization] if params.key?(:applied_to_organization)
      tax.save!

      manage_taxes_on_billing_entity if params.key?(:applied_to_organization)

      customer_ids = (customer_ids + tax.reload.applicable_customers.select(:id)).uniq
      draft_invoices = tax.organization.invoices.where(customer_id: customer_ids).draft
      draft_invoices.update_all(ready_to_be_refreshed: true) # rubocop:disable Rails/SkipsModelValidations

      result.tax = tax
      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    end

    private

    attr_reader :tax, :params

    def manage_taxes_on_billing_entity
      billing_entity = tax.organization.default_billing_entity
      if tax.applied_to_organization
        BillingEntities::Taxes::ApplyTaxesService.call(billing_entity:, tax_codes: [tax.code])
      else
        BillingEntities::Taxes::RemoveTaxesService.call(billing_entity:, tax_codes: [tax.code])
      end
    end
  end
end
