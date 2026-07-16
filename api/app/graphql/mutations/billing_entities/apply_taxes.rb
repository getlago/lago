# frozen_string_literal: true

module Mutations
  module BillingEntities
    class ApplyTaxes < ::Mutations::BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "billing_entities:update"

      argument :billing_entity_id, ID, required: true
      argument :tax_codes, [String], required: true

      field :applied_taxes, [Types::Taxes::Object], null: false

      def resolve(billing_entity_id:, tax_codes:)
        billing_entity = current_organization.billing_entities.find(billing_entity_id)
        result = ::BillingEntities::Taxes::ApplyTaxesService.call(billing_entity:, tax_codes:)

        result.success? ? {applied_taxes: result.taxes_to_apply || []} : result_error(result)
      end
    end
  end
end
