# frozen_string_literal: true

module Resolvers
  class WebhookEndpointsResolver < Resolvers::BaseResolver
    include AuthenticableApiUser
    include RequiredOrganization

    REQUIRED_PERMISSION = "developers:manage"

    description "Query webhook endpoints of an organization"

    argument :limit, Integer, required: false
    argument :page, Integer, required: false
    argument :search_term, String, required: false

    type Types::WebhookEndpoints::Object.collection_type, null: false

    def resolve(ids: nil, page: nil, limit: nil, search_term: nil)
      result = ::WebhookEndpointsQuery.call(
        organization: current_organization,
        search_term:,
        pagination: {
          page:,
          limit:
        }
      )

      result.webhook_endpoints
    end
  end
end
