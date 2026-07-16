# frozen_string_literal: true

module Resolvers
  class QuoteVersionResolver < Resolvers::BaseResolver
    include AuthenticableApiUser
    include RequiredOrganization

    REQUIRED_PERMISSION = "quotes:view"

    description "Query a single quote version"

    argument :id, ID, required: true, description: "Lago ID of the quote version"

    type Types::QuoteVersions::Object, null: true

    def resolve(id:)
      current_organization.quote_versions.find(id)
    rescue ActiveRecord::RecordNotFound
      not_found_error(resource: "quote_version")
    end
  end
end
