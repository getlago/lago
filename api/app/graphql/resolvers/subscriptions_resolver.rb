# frozen_string_literal: true

module Resolvers
  class SubscriptionsResolver < Resolvers::BaseResolver
    include AuthenticableApiUser
    include RequiredOrganization

    REQUIRED_PERMISSION = "subscriptions:view"

    description "Query subscriptions of an organization"

    argument :billing_entity_ids, [ID], required: false
    argument :currency, String, required: false
    argument :external_customer_id, String, required: false
    argument :external_id, String, required: false
    argument :limit, Integer, required: false
    argument :overriden, Boolean, required: false
    argument :page, Integer, required: false
    argument :plan_code, String, required: false
    argument :search_term, String, required: false
    argument :status, [Types::Subscriptions::StatusTypeEnum], required: false

    type Types::Subscriptions::Object.collection_type, null: false

    def resolve(
      page: nil,
      limit: nil,
      plan_code: nil,
      status: nil,
      external_id: nil,
      external_customer_id: nil,
      overriden: nil,
      search_term: nil,
      currency: nil,
      billing_entity_ids: nil
    )
      # In FE we include next subscription in the list, so we need to exclude subscriptions with previous subscription from the list
      result = SubscriptionsQuery.call(
        organization: current_organization,
        pagination: {page:, limit:},
        filters: {
          plan_code:,
          status:,
          external_id:,
          external_customer_id:,
          overriden:,
          currency:,
          billing_entity_ids:,
          exclude_next_subscriptions: true
        },
        search_term:
      )

      result.subscriptions.preload(
        {next_subscriptions: :plan},
        {customer: :billing_entity}
      )
    end
  end
end
