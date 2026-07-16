# frozen_string_literal: true

module Mutations
  module IntegrationItems
    class FetchAccounts < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "organization:integrations:update"

      graphql_name "FetchIntegrationAccounts"
      description "Fetch integration accounts"

      argument :integration_id, ID, required: true

      type Types::IntegrationItems::Object.collection_type, null: false

      def resolve(**args)
        integration = current_organization.integrations.find_by(id: args[:integration_id])

        ::Integrations::Aggregator::SyncService.call(integration:, options: {only_accounts: true})

        result = ::Integrations::Aggregator::AccountsService.call(integration:)

        result.success? ? result.accounts : result_error(result)
      end
    end
  end
end
