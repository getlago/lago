# frozen_string_literal: true

module BillingEntities
  module Taxes
    class ApplyTaxesService < BaseService
      Result = BaseResult[:applied_taxes, :taxes_to_apply]

      def initialize(billing_entity:, tax_codes:)
        @billing_entity = billing_entity
        @tax_codes = tax_codes

        super
      end

      def call
        return result if tax_codes.blank?

        find_taxes_on_organization
        return result if result.failure?

        result.applied_taxes = result.taxes_to_apply.map do |tax|
          billing_entity.applied_taxes
            .create_with(organization_id: tax.organization_id)
            .find_or_create_by!(tax:)
        end
        refresh_draft_invoices

        result
      end

      private

      attr_reader :billing_entity, :tax_codes

      delegate :organization, to: :billing_entity

      def find_taxes_on_organization
        result.taxes_to_apply = organization.taxes.where(code: tax_codes)

        if result.taxes_to_apply.count != tax_codes.count
          result.not_found_failure!(resource: "tax")
        end
      end
    end
  end
end
