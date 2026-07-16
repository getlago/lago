# frozen_string_literal: true

module Resolvers
  class TaxResolver < Resolvers::BaseResolver
    include AuthenticableApiUser
    include RequiredOrganization

    description "Query a single tax of an organization"

    argument :id, ID, required: true, description: "Uniq ID of the tax"

    type Types::Taxes::Object, null: true

    def resolve(id: nil)
      current_organization.taxes.find(id)
    rescue ActiveRecord::RecordNotFound
      not_found_error(resource: "tax")
    end
  end
end
