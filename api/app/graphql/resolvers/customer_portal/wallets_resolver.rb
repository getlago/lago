# frozen_string_literal: true

module Resolvers
  module CustomerPortal
    class WalletsResolver < Resolvers::BaseResolver
      include AuthenticableCustomerPortalUser

      description "Query wallets"

      argument :limit, Integer, required: false
      argument :page, Integer, required: false
      argument :status, Types::Wallets::StatusEnum, required: false

      type Types::CustomerPortal::Wallets::Object.collection_type, null: false

      def resolve(page: nil, limit: nil, status: nil)
        wallets = context[:customer_portal_user].wallets
        wallets = status.present? ? wallets.where(status:) : wallets.active
        wallets
          .page(page)
          .per(limit)
          .order(:priority, :created_at)
      rescue ActiveRecord::RecordNotFound
        not_found_error(resource: "customer")
      end
    end
  end
end
