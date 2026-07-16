# frozen_string_literal: true

module Resolvers
  class IntegrationsResolver < Resolvers::BaseResolver
    include AuthenticableApiUser
    include RequiredOrganization

    REQUIRED_PERMISSION = %w[organization:integrations:view customers:view]

    description "Query organization's integrations"

    argument :limit, Integer, required: false
    argument :page, Integer, required: false
    argument :types, [Types::Integrations::IntegrationTypeEnum], required: false

    type Types::Integrations::Object.collection_type, null: true

    def resolve(types: nil, page: nil, limit: nil)
      scope = current_organization.integrations.page(page).per(limit)
      scope = scope.where(type: types(types)) if types.present?
      scope
    end

    private

    def types(input)
      input.map { |type| ::Integrations::BaseIntegration.integration_type(type) }
    end
  end
end
