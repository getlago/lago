# frozen_string_literal: true

module Resolvers
  module CustomerPortal
    class WalletResolver < Resolvers::BaseResolver
      include AuthenticableCustomerPortalUser

      description "Query a single wallet from the customer portal"

      argument :id, ID, required: true, description: "Uniq ID of the wallet"

      type Types::CustomerPortal::Wallets::Object, null: true

      def resolve(id: nil)
        context[:customer_portal_user].wallets.find(id)
      rescue ActiveRecord::RecordNotFound
        not_found_error(resource: "wallet")
      end
    end
  end
end
