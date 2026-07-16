# frozen_string_literal: true

module Resolvers
  class EventsResolver < Resolvers::BaseResolver
    include AuthenticableApiUser
    include RequiredOrganization

    MAX_LIMIT = 1000

    description "Query events of an organization"

    argument :limit, Integer, required: false
    argument :page, Integer, required: false

    type Types::Events::Object.collection_type, null: true

    def resolve(page: nil, limit: nil)
      if current_organization.clickhouse_events_store?
        Clickhouse::EventsRaw.where(organization_id: current_organization.id)
          .order(ingested_at: :desc)
          .page(page)
          .per((limit >= MAX_LIMIT) ? MAX_LIMIT : limit)
      else
        current_organization.events
          .order(created_at: :desc)
          .page(page)
          .per((limit >= MAX_LIMIT) ? MAX_LIMIT : limit)
      end
    end
  end
end
