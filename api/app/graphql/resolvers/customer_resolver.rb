# frozen_string_literal: true

module Resolvers
  class CustomerResolver < Resolvers::BaseResolver
    include AuthenticableApiUser
    include RequiredOrganization

    REQUIRED_PERMISSION = "customers:view"

    description "Query a single customer of an organization"

    argument :external_id, ID, required: false, description: "External ID of the customer"
    argument :id, ID, required: false, description: "Lago ID of the customer"

    type Types::Customers::Object, null: true

    def resolve(id: nil, external_id: nil)
      if id.nil? && external_id.nil?
        raise GraphQL::ExecutionError, "You must provide either `id` or `external_id`."
      end

      return current_organization.customers.find(id) if id.present?
      current_organization.customers.find_by!(external_id:)
    rescue ActiveRecord::RecordNotFound
      not_found_error(resource: "customer")
    end
  end
end
