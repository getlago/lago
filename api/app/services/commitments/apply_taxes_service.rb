# frozen_string_literal: true

module Commitments
  class ApplyTaxesService < BaseService
    Result = BaseResult[:applied_taxes]

    def initialize(commitment:, tax_codes:)
      @commitment = commitment
      @tax_codes = tax_codes

      super
    end

    def call
      return result.not_found_failure!(resource: "commitment") unless commitment
      return result.not_found_failure!(resource: "tax") if (tax_codes - taxes.pluck(:code)).present?

      commitment.applied_taxes.where(
        tax_id: commitment.taxes.where.not(code: tax_codes).pluck(:id)
      ).destroy_all

      result.applied_taxes = tax_codes.map do |tax_code|
        commitment.applied_taxes
          .create_with(organization_id: commitment.plan.organization_id)
          .find_or_create_by!(tax: taxes.find_by(code: tax_code))
      end

      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    end

    private

    attr_reader :commitment, :tax_codes

    def taxes
      @taxes ||= commitment.plan.organization.taxes.where(code: tax_codes)
    end
  end
end
