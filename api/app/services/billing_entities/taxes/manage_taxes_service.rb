# frozen_string_literal: true

module BillingEntities
  module Taxes
    class ManageTaxesService < BaseService
      Result = BaseResult[:taxes, :applied_taxes]

      def initialize(billing_entity:, tax_codes:)
        @billing_entity = billing_entity
        @tax_codes = tax_codes || []

        super
      end

      def call
        return result.not_found_failure!(resource: "billing_entity") unless billing_entity

        manage_taxes
        refresh_draft_invoices
        result
      end

      private

      attr_reader :billing_entity, :tax_codes

      delegate :organization, to: :billing_entity

      def manage_taxes
        # Remove duplicates and normalize case
        unique_tax_codes = tax_codes.uniq.map(&:upcase)
        taxes = organization.taxes.where("UPPER(code) IN (?)", unique_tax_codes)

        if taxes.count != unique_tax_codes.count
          result.not_found_failure!(resource: "tax")
          return
        end

        billing_entity.applied_taxes = taxes.map do |tax|
          BillingEntity::AppliedTax.new(billing_entity:, tax:, organization:)
        end

        result.taxes = taxes
        result.applied_taxes = billing_entity.applied_taxes
      end
    end
  end
end
