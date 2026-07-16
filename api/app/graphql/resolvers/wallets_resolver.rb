# frozen_string_literal: true

module Resolvers
  class WalletsResolver < Resolvers::BaseResolver
    include AuthenticableApiUser
    include RequiredOrganization

    description "Query wallets"

    argument :customer_id, ID, required: true, description: "Uniq ID of the customer"
    argument :ids, [ID], required: false, description: "List of wallet IDs to fetch"
    argument :limit, Integer, required: false
    argument :page, Integer, required: false
    argument :status, Types::Wallets::StatusEnum, required: false

    type Types::Wallets::Object.collection_type(metadata_type: Types::Wallets::Metadata), null: false

    def resolve(customer_id: nil, ids: nil, page: nil, limit: nil, status: nil)
      current_customer = current_organization.customers.find(customer_id)

      wallets = current_customer
        .wallets
        .page(page)
        .per(limit)

      wallets = wallets.where(status:) if status.present?
      wallets = wallets.where(id: ids) if ids.present?

      wallets.order(status: :asc, created_at: :desc)
    rescue ActiveRecord::RecordNotFound
      not_found_error(resource: "customer")
    end
  end
end
