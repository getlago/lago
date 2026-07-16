# frozen_string_literal: true

module Resolvers
  class BillingEntityResolver < Resolvers::BaseResolver
    include AuthenticableApiUser
    include RequiredOrganization

    REQUIRED_PERMISSION = "billing_entities:view"

    description "Query a single billing_entity of an organization"

    argument :code, String, required: true, description: "Code of the billing_entity"

    type Types::BillingEntities::Object, null: true

    def resolve(code:)
      current_organization.all_billing_entities.find_by!(code:)
    rescue ActiveRecord::RecordNotFound
      not_found_error(resource: "billing_entity")
    end
  end
end
