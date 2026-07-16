# frozen_string_literal: true

module FixedCharges
  class ApplyTaxesService < BaseService
    Result = BaseResult[:applied_taxes]

    def initialize(fixed_charge:, tax_codes:)
      @fixed_charge = fixed_charge
      @tax_codes = tax_codes

      super
    end

    def call
      return result.not_found_failure!(resource: "fixed_charge") unless fixed_charge
      return result.not_found_failure!(resource: "tax") if (tax_codes - taxes.pluck(:code)).present?

      fixed_charge.applied_taxes.where(
        tax_id: fixed_charge.taxes.where.not(code: tax_codes).pluck(:id)
      ).destroy_all

      result.applied_taxes = tax_codes.map do |tax_code|
        fixed_charge.applied_taxes
          .create_with(organization_id: fixed_charge.organization_id)
          .find_or_create_by!(tax: taxes.find_by(code: tax_code))
      end

      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    end

    private

    attr_reader :fixed_charge, :tax_codes

    def taxes
      @taxes ||= fixed_charge.plan.organization.taxes.where(code: tax_codes)
    end
  end
end
