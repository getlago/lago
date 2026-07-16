# frozen_string_literal: true

module Resolvers
  class SubscriptionResolver < Resolvers::BaseResolver
    include AuthenticableApiUser
    include RequiredOrganization

    REQUIRED_PERMISSION = "subscriptions:view"

    description "Query a single subscription of an organization"

    argument :external_id, ID, required: false, description: "External ID of the subscription"
    argument :id, ID, required: false, description: "Lago ID of the subscription"

    type Types::Subscriptions::Object, null: true

    def resolve(id: nil, external_id: nil)
      if id.nil? && external_id.nil?
        raise GraphQL::ExecutionError, "You must provide either `id` or `external_id`."
      end

      return current_organization.subscriptions.find(id) if id.present?

      current_organization.subscriptions
        .order("terminated_at DESC NULLS FIRST, started_at DESC")
        .find_by!(external_id:)
    rescue ActiveRecord::RecordNotFound
      not_found_error(resource: "subscription")
    end
  end
end
