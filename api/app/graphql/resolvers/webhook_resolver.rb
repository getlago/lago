# frozen_string_literal: true

module Resolvers
  class WebhookResolver < Resolvers::BaseResolver
    include AuthenticableApiUser
    include RequiredOrganization

    REQUIRED_PERMISSION = "developers:manage"

    description "Query a webhook"

    argument :id, ID, required: true

    type Types::Webhooks::Object, null: true

    def resolve(id:)
      current_organization.webhooks.find(id)
    rescue ActiveRecord::RecordNotFound
      not_found_error(resource: "webhook")
    end
  end
end
