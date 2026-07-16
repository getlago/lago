# frozen_string_literal: true

module BillingEntities
  class ChangeEuTaxManagementService < BaseService
    Result = BaseResult[:billing_entity]

    ERROR_CODE = "billing_entity_must_be_in_eu"

    def initialize(billing_entity:, eu_tax_management:)
      @billing_entity = billing_entity
      @eu_tax_management = eu_tax_management

      super
    end

    def call
      return result.not_found_failure!(resource: "billing_entity") unless billing_entity

      if !billing_entity.eu_vat_eligible? && eu_tax_management
        return result.single_validation_failure!(error_code: ERROR_CODE, field: :eu_tax_management)
      end

      billing_entity.eu_tax_management = eu_tax_management

      # NOTE: autogenerate service generates taxes.
      #       Taxes belong to organization, but can be applied to the billing_entity,
      #       So we auto generate taxes for the billing_entity organization
      ::Taxes::AutoGenerateService.call(organization: billing_entity.organization) if eu_tax_management

      result.billing_entity = billing_entity
      result
    end

    private

    attr_reader :billing_entity, :eu_tax_management
  end
end
