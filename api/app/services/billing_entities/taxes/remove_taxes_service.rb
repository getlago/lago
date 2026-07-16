# frozen_string_literal: true

module BillingEntities
  module Taxes
    class RemoveTaxesService < BaseService
      Result = BaseResult[:taxes_to_remove]

      def initialize(billing_entity:, tax_codes:)
        @billing_entity = billing_entity
        @tax_codes = tax_codes

        super
      end

      def call
        return result if tax_codes.blank?

        find_taxes_to_remove
        return result if result.failure?

        billing_entity.applied_taxes.where(tax: result.taxes_to_remove).destroy_all
        refresh_draft_invoices

        result
      end

      private

      attr_reader :billing_entity, :tax_codes

      delegate :organization, to: :billing_entity

      def find_taxes_to_remove
        result.taxes_to_remove = organization.taxes.where(code: tax_codes)
        if result.taxes_to_remove.count != tax_codes.count
          result.not_found_failure!(resource: "tax")
        end
      end

      def remove_taxes
        @billing_entity.applied_taxes.where(tax: @taxes).destroy_all
      end
    end
  end
end
