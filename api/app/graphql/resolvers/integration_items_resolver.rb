# frozen_string_literal: true

module Resolvers
  class IntegrationItemsResolver < Resolvers::BaseResolver
    include AuthenticableApiUser
    include RequiredOrganization

    REQUIRED_PERMISSION = "organization:integrations:view"

    description "Query integration items of an integration"

    argument :integration_id, ID, required: true
    argument :item_type, Types::IntegrationItems::ItemTypeEnum, required: false
    argument :limit, Integer, required: false
    argument :page, Integer, required: false
    argument :search_term, String, required: false

    type Types::IntegrationItems::Object.collection_type, null: false

    def resolve(integration_id:, page: nil, limit: nil, search_term: nil, item_type: nil)
      integration = current_organization.integrations.where(id: integration_id).first

      return not_found_error(resource: "integration") unless integration

      result = ::IntegrationItemsQuery.call(
        organization: current_organization,
        search_term:,
        filters: {
          integration_id:,
          item_type:
        },
        pagination: {
          page:,
          limit:
        }
      )

      result.integration_items
    end
  end
end
