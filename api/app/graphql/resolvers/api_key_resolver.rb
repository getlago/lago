# frozen_string_literal: true

module Resolvers
  class ApiKeyResolver < Resolvers::BaseResolver
    include AuthenticableApiUser
    include RequiredOrganization

    REQUIRED_PERMISSION = "developers:keys:manage"

    argument :id, ID, required: true, description: "Uniq ID of the API key"

    description "Query the API key"

    type Types::ApiKeys::Object, null: false

    def resolve(id: nil)
      current_organization.api_keys.find(id)
    rescue ActiveRecord::RecordNotFound
      not_found_error(resource: "api_key")
    end
  end
end
