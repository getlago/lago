# frozen_string_literal: true

module Resolvers
  class ApiKeysResolver < Resolvers::BaseResolver
    include AuthenticableApiUser
    include RequiredOrganization

    REQUIRED_PERMISSION = "developers:keys:manage"

    description "Query the API keys of current organization"

    argument :limit, Integer, required: false
    argument :page, Integer, required: false

    type Types::ApiKeys::SanitizedObject.collection_type, null: false

    def resolve(page: nil, limit: nil)
      current_organization.api_keys.order(created_at: :asc).page(page).per(limit)
    end
  end
end
