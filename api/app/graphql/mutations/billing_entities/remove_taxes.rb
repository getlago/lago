# frozen_string_literal: true

module Mutations
  module BillingEntities
    class RemoveTaxes < ::Mutations::BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "billing_entities:update"

      argument :billing_entity_id, ID, required: true
      argument :tax_codes, [String], required: true

      field :removed_taxes, [Types::Taxes::Object], null: false

      def resolve(billing_entity_id:, tax_codes:)
        billing_entity = current_organization.billing_entities.find(billing_entity_id)
        result = ::BillingEntities::Taxes::RemoveTaxesService.call(billing_entity:, tax_codes:)

        result.success? ? {removed_taxes: result.taxes_to_remove || []} : result_error(result)
      end
    end
  end
end
