# frozen_string_literal: true

module Resolvers
  module Integrations
    class SubsidiariesResolver < Resolvers::BaseResolver
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "organization:integrations:view"

      description "Query integration subsidiaries"

      argument :integration_id, ID, required: false

      type Types::Integrations::Subsidiaries::Object.collection_type, null: true

      def resolve(integration_id: nil)
        integration = current_organization.integrations.find(integration_id)

        result = ::Integrations::Aggregator::SubsidiariesService.call(integration:)

        result.subsidiaries
      end
    end
  end
end
