# frozen_string_literal: true

module Resolvers
  class OrderResolver < Resolvers::BaseResolver
    include AuthenticableApiUser
    include RequiredOrganization

    REQUIRED_PERMISSION = "orders:view"

    description "Query a single order"

    argument :id, ID, required: true, description: "Uniq ID of the order"

    type Types::Orders::Object, null: true

    def resolve(id:)
      current_organization.orders.find(id)
    rescue ActiveRecord::RecordNotFound
      not_found_error(resource: "order")
    end
  end
end
