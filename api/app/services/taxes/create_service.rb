# frozen_string_literal: true

module Taxes
  class CreateService < BaseService
    Result = BaseResult[:tax]

    def initialize(organization:, params:)
      @organization = organization
      @params = params

      super
    end

    def call
      tax = organization.taxes.new(
        name: params[:name],
        code: params[:code],
        rate: params[:rate],
        description: params[:description]
      )

      tax.applied_to_organization = params[:applied_to_organization] if params.key?(:applied_to_organization)
      tax.save!

      apply_taxes_on_billing_entity if params[:applied_to_organization]

      result.tax = tax
      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    end

    private

    attr_reader :organization, :params

    def apply_taxes_on_billing_entity
      billing_entity = organization.default_billing_entity
      if params[:applied_to_organization]
        BillingEntities::Taxes::ApplyTaxesService.call(billing_entity:, tax_codes: [params[:code]])
      end
    end
  end
end
