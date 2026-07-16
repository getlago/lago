# frozen_string_literal: true

module AddOns
  class ApplyTaxesService < BaseService
    Result = BaseResult[:applied_taxes]

    def initialize(add_on:, tax_codes:)
      @add_on = add_on
      @tax_codes = tax_codes

      super
    end

    def call
      return result.not_found_failure!(resource: "add_on") unless add_on
      return result.not_found_failure!(resource: "tax") if (tax_codes - taxes.pluck(:code)).present?

      add_on.applied_taxes.where(
        tax_id: add_on.taxes.where.not(code: tax_codes).pluck(:id)
      ).destroy_all

      result.applied_taxes = tax_codes.map do |tax_code|
        add_on.applied_taxes
          .create_with(organization: add_on.organization)
          .find_or_create_by!(tax: taxes.find_by(code: tax_code))
      end

      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    end

    private

    attr_reader :add_on, :tax_codes

    def taxes
      @taxes ||= add_on.organization.taxes.where(code: tax_codes)
    end
  end
end
