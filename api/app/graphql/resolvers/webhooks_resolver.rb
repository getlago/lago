# frozen_string_literal: true

module Resolvers
  class WebhooksResolver < Resolvers::BaseResolver
    include AuthenticableApiUser
    include RequiredOrganization

    REQUIRED_PERMISSION = "developers:manage"

    description "Query Webhooks"

    argument :event_types, [String], required: false
    argument :from_date, GraphQL::Types::ISO8601DateTime, required: false
    argument :http_statuses, [String], required: false
    argument :limit, Integer, required: false
    argument :page, Integer, required: false
    argument :search_term, String, required: false
    argument :status, Types::Webhooks::StatusEnum, required: false # TODO: remove :status after migrating to :statuses
    argument :statuses, [Types::Webhooks::StatusEnum], required: false
    argument :to_date, GraphQL::Types::ISO8601DateTime, required: false
    argument :webhook_endpoint_id, String, required: true

    type Types::Webhooks::Object.collection_type, null: false

    def resolve(webhook_endpoint_id:, page: nil, limit: nil, search_term: nil, status: nil, statuses: nil, event_types: nil, http_statuses: nil, from_date: nil, to_date: nil)
      # TODO: remove :status after migrating to :statuses
      statuses_filter = statuses || (status.present? ? [status] : nil)

      result = WebhooksQuery.call(
        organization: current_organization,
        search_term:,
        filters: {
          webhook_endpoint_id:,
          statuses: statuses_filter,
          event_types:,
          http_statuses:,
          from_date:,
          to_date:
        },
        pagination: {
          page:,
          limit:
        }
      )

      result.webhooks
    end
  end
end
