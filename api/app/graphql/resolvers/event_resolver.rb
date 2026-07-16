# frozen_string_literal: true

module Resolvers
  class EventResolver < Resolvers::BaseResolver
    include AuthenticableApiUser
    include RequiredOrganization

    description "Query a single event of an organization"

    argument :transaction_id, ID, required: true, description: "Transaction ID of the event"

    type Types::Events::Object, null: true

    def resolve(transaction_id: nil)
      event_scope = current_organization.clickhouse_events_store? ? Clickhouse::EventsRaw : Event
      event_scope.find_by!(organization_id: current_organization.id, transaction_id:)
    rescue ActiveRecord::RecordNotFound
      not_found_error(resource: "event")
    end
  end
end
