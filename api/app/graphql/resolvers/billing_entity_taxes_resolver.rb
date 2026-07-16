# frozen_string_literal: true

module Resolvers
  class BillingEntityTaxesResolver < Resolvers::BaseResolver
    include AuthenticableApiUser
    include RequiredOrganization

    description "Query taxes of a billing entity"
    argument :billing_entity_id, ID, required: true, description: "Uniq ID of the billing entity"

    type Types::Taxes::Object.collection_type, null: false

    def resolve(billing_entity_id:)
      billing_entity = current_organization.billing_entities.find(billing_entity_id)
      billing_entity.taxes
    rescue ActiveRecord::RecordNotFound
      not_found_error(resource: "billing_entity")
    end
  end
end
