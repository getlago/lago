# frozen_string_literal: true

module Resolvers
  class AddOnResolver < Resolvers::BaseResolver
    include AuthenticableApiUser
    include RequiredOrganization

    REQUIRED_PERMISSION = "addons:view"

    description "Query a single add-on of an organization"

    argument :id, ID, required: true, description: "Uniq ID of the add-on"

    type Types::AddOns::Object, null: true

    def resolve(id: nil)
      current_organization.add_ons.find(id)
    rescue ActiveRecord::RecordNotFound
      not_found_error(resource: "add_on")
    end
  end
end
