# frozen_string_literal: true

module Mutations
  module IntegrationItems
    class FetchItems < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "organization:integrations:update"

      graphql_name "FetchIntegrationItems"
      description "Fetch integration items"

      argument :integration_id, ID, required: true

      type Types::IntegrationItems::Object.collection_type, null: false

      def resolve(**args)
        integration = current_organization.integrations.find_by(id: args[:integration_id])

        ::Integrations::Aggregator::SyncService.call(integration:, options: {only_items: true})

        result = ::Integrations::Aggregator::ItemsService.call(integration:)

        result.success? ? result.items : result_error(result)
      end
    end
  end
end
